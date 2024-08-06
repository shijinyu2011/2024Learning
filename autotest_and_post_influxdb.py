$ cat ./build/common/autotest.py
import os
import requests
import json
import time
import sys

get_available_url="http://192.168.100.101:9001/api/worker/v1/GetAvailable"

def create_task(data):
    print("wait available board ...")
    url = "http://192.168.50.116:7000/api/manager/v1/boards/CreateJenkinsTask"
    res = requests.post(url=url, data=json.dumps(data)).json()
    if res.get("code") == "0":
        print(data)
        print(res["msg"],flush=True)
    return res.get("code")

def login():
    data = {
        "userName": "baoyujia",
        "pwd": "12345678"
    }
    common_url = "http://localhost:7000"
    login_api = "/api/manager/v1/login"
    res = requests.session().post(url=f"{common_url}{login_api}", data=json.dumps(data)).json()
    print(res["msg"])
    if res["code"] != 0:
        print(f"[ERROR]: {res['msg']},请检查用户名密码是否输入正确")
        sys.exit(res["code"])
    token = res["token"]
    return token

def main():
    data={}
    params=["NDS_BUILD_DIR","NDS_BUILD_VER","NDS_MODEL_ROOT","NDS_CODE_AUTHOR","NDS_CHIP_TYPE","NDS_TEST_VER","CODE_BRANCH","NDS_TOP_OUT_DIR",
            "NDS_MODEL_DIR","NDS_TEST_TIMES","NDS_UNIT_DSP_DIR","GENMODEL_TYPE","NDS_TEST_METHOD","NDS_CASE_SUBDIR","NDS_TEST_DURATION","BOARD_NAME","NDS_TEST_TIMES","NDS_BUILD_TYPE","BUILD_NUMBER","TEST_CASE","NODE_LABEL","NDS_TEST_DEBUGGER"]
    for param in params:
        if os.environ.get(param,""):
            data[param]=os.environ.get(param,"")
    if "NDS_TEST_TIMES" not in data.keys():
        data["NDS_TEST_TIMES"]=1
    if os.environ.get("BOARD_NAME")=="N16X_DDR4_2048MB":
        data["memory"]="2G"
    while True:
        time.sleep(3)
        ret=create_task(data)
        if ret == "0":
            break
    test_ver=os.environ.get("NDS_TEST_VER")
    retry_time=os.environ.get("NDS_TEST_TIMES",1)
    case_name=os.environ.get("TEST_CASE")
    build_num=os.environ.get("BUILD_NUMBER")
    while True:
        DBHOST = "192.168.50.114"
        DBPORT = "8086"
        if "/" in case_name:
            qeury_sql = "select dev,log,terr,retry from autotest where case='{}' and ver='{}' and retry={} and job='{}';".format(
            case_name, test_ver, retry_time, build_num)
        else:
            qeury_sql = "select dev,log,terr,retry from autotest where case=~/{}$/ and ver='{}' and retry={} and job='{}';".format(
                case_name, test_ver, retry_time, build_num)
        query_message = 'curl -s -G  http://{}:{}/query --data-urlencode "db=nds" --data-urlencode "q={}"'.format(
            DBHOST, DBPORT, qeury_sql)
        if case_name=='cms30_x3c_mipi2_1920x720_sl_B':
            print(query_message,flush=True)
        res = os.popen(query_message).read()
        if res == "":
            continue
        else:
            res_dict = eval(res)
            print(res_dict,flush=True)
            series_list = res_dict['results'][0].get('series')
            values_list = []
            if series_list:
                values_list = series_list[0]['values'][0]
                time_str = values_list[0].split("T")[0].replace("-","/")
                board_name = values_list[1]
                log_num=str(int(retry_time)-1)
                log_dir=f"/nds/log/test/{time_str}/{board_name}/{build_num}"
                print(f"log_dir:{log_dir}")
                return_code = values_list[-2]
                if "main.log" in values_list[2]:
                    logfo=os.path.join("/nds",values_list[2])
                else:
                    if os.path.exists(f"{log_dir}/{log_num}.log"):
                        logfo=f"{log_dir}/{log_num}.log"
                    elif os.path.exists(f"{log_dir}/main.log"):
                        logfo=f"{log_dir}/main.log"
                    else:
                        logfo=os.path.join("/nds",values_list[2])
                os.system(f"cat {logfo}")
                if values_list[-2]=="0":
                   print("success !!!")
                   return 0
                else:
                    return int(values_list[-2])
            else:
                time.sleep(7)



if __name__ == '__main__':
    sys.exit(main())

jinyushi@jinyushi MINGW32 ~/PycharmProjects/pythonProject/nds (master)
$

+++++++++++++++++++++++ post data to influxdb +++++++++++++++++++++++++++++++++++++++++++
$ cat common/savedb.sh
#!/bin/bash
#set -xe

help() {
  echo "Usage: $0 <unit-name> <err-code> <duration> <logfile>"
}

init() {
  if [ -z "$4" ]; then
    help
    exit 1
  fi
  [ -n "$NDS_LOG_ROOT" ] || NDS_LOG_ROOT=/nds/log
  [ -n "$NDS_DB_NAME" ] || NDS_DB_NAME=autobuild
  [ -n "$NDS_ROOT_DISK" ] || NDS_ROOT_DISK=n:
}

logmsg() {
  local ts=$(date "+%m/%d/%Y %H:%M:%S")
  echo $ts $*
}

savedb()
{

  local unit=$1
  local terr=$2
  local dur=$3

  logmsg "savedb start1"
  logmsg $4

  local logfile=$(echo $4 | sed "s#^$NDS_ROOT_DISK#/nds#i" | sed 's#\\#/#g' | sed "s#^$NDS_LOG_ROOT/##")

  logmsg "savedb start2"
  logmsg $logfile

  logmsg "savedb(unit: $unit, err: $terr, duration: $dur)"
  local cerr=0
  [ $terr -eq 0 ] || cerr=1
  local jobname=$JOB_NAME
  [ -n "$jobname" ] || jobname=manual
  local jobid=$BUILD_NUMBER
  [ -n "$jobid" ] || jobid=0
  local ver=$NDS_BUILD_VER
  [ -n "$ver" ] || ver=unknown
  local dev=$NODE_NAME
  [ -n "$dev" ] || dev=$HOSTNAME
  local tags="case=$unit,job=$jobname,dev=$dev,terr=$terr,ver=$ver"
  local vals="id=$jobid,cerr=$cerr,dur=$dur,log=\"$logfile\""
  if [[ x"$NDS_BUILD_TYPE" == x"daily" ]];then
      echo "curl -m 10 -s -XPOST \"http://influxdb.nds.nextvpu.com:8086/write?db=nds\" \
        --data-binary \"$NDS_DB_NAME,$tags $vals\""
      curl -m 10 -s -XPOST "http://influxdb.nds.nextvpu.com:8086/write?db=nds" \
        --data-binary "$NDS_DB_NAME,$tags $vals"
  else
      echo "It is not daily job, not save DB."
  fi

  local rc=$?
  logmsg "savedb(unit: $unit, err: $terr, duration: $dur)... $rc"
  return $rc
}

main() {
  init $*
  savedb $*
}

main $*


jinyushi@jinyushi MINGW32 ~/PycharmProjects/pythonProject/nds (master)
$


