


jenkins@19491072226f:/nds/build/debug$ cat run_tableReadApp.sh
#/bin/bash

#device     :   table reader device
#work_dir   :   store apk path
#input_medium_path:   source destination, store test pic path
#dest_path:      destination path, default is POST and MITSUI,
#                                                  /sdcard/nvp/TestBankbook/images/MITSUI
#                                              or /sdcard/nvp/TestBankbook/images/POST
#apk_name:      need to install apk_name

device=$1
work_dir=$2
input_medium_path=$3
dest_path=$4
apk_name=${5:-'test-bankbook-debug.apk'}

export PATH=$PATH:/nds/build/debug/platform-tools
adb version

echo "device is $device,apk_name is $apk_name"

adb -s $device uninstall com.example.test_bankbook

apk_path="$work_dir/$apk_name"
echo "apk path is $apk_path"
adb -s $device install -t $apk_path


adb -s $device shell rm -rf  /sdcard/nvp/TestBankbook/*

images_dest_path="/sdcard/nvp/TestBankbook/images/$dest_path"
echo "images_dest_path is $images_dest_path"
adb -s $device push $input_medium_path $images_dest_path

adb -s $device shell am start -n com.example.test_bankbook/.MainActivity

adb -s $device shell test -f /sdcard/nvp/TestBankbook/testOver.txt

finish_flag=$?
echo "finish_flag is $finish_flag"

echo "start"
date "+%m/%d/%Y %H:%M:%S"

check_num=30
num=1
while [[ $finish_flag -gt 0 && $num -lt  $check_num ]]
do

        echo "test is ongoing, num is $num, finish flag is $finish_flag, wait it ....."
        sleep 60
        ((num=num+1))
        adb -s $device shell test -f /sdcard/nvp/TestBankbook/testOver.txt
        finish_flag=$?
done
echo "end"
date "+%m/%d/%Y %H:%M:%S"

adb -s $device pull  /sdcard/nvp/TestBankbook/results $work_dir

[ $? -eq 0 ] || echo "run failed" && exit 1
echo "done it. ok."




