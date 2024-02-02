import groovy.transform.Field
import groovy.json.JsonSlurper
@Field final List whiteList = []
@Field final String ssh_option = 'ssh -p 29418 scm@10.0.7.214 gerrit '
@Field final String query_option = 'query --format JSON --current-patch-set --files status:open '

Boolean projectInWhiteList(String project){
     return whiteList.any{it.contains(project+":")}
}

Boolean fileInWhiteList(String project,String libFile){
    return whiteList.contains(project+":") || whiteList.contains(project+":"+libFile)
}

List getChangedFiles(String GERRIT_CHANGE_NUMBER){
    return sh( returnStdout: true, script:"""#!/bin/bash -x
        $ssh_option $query_option change:$GERRIT_CHANGE_NUMBER|jq -r .currentPatchSet.files|grep -v 'null'|jq -r '.[]|select(.type != "DELETED")|.file'
    """).trim()?.tokenize('\n')
}

List getLibFiles(List changedFiles){
    List libFiles = []
    changedFiles.each{ String file->
        List suffix = file.tokenize('.')
        if(suffix.last().equals('a')||suffix.last().equals('so')){
           libFiles.add(file)
        }
    }
    return libFiles
}

def codeVerify(String label="0", String msg="", String change, String patchSet){
    commandExitCode = sh( returnStatus: true, script:"""#!/bin/bash -x
        $ssh_option review --verified $label  --message '"${msg}"' ${change},${patchSet} > /tmp/${env.BUILD_NUMBER} 2>&1
    """)
    commandOutput = readFile("/tmp/${env.BUILD_NUMBER}")
    ThrowExceptionOnError(commandExitCode,commandOutput)
}

def ThrowExceptionOnError(Integer retCode, String message){
    if (retCode){
        error "Error happened, ERROR[${retCode}]: ${message}"
    }
}

Map checkWhiteList(){
        whiteList = readFile('/home/scm/jenkins/script/trigger_214/config/white.list').tokenize('\n').collect{elm-> elm.replaceAll("\\s","")}
        String GERRIT_PROJECT = env.GERRIT_PROJECT  //"AVM/SOC/project"
        String GERRIT_CHANGE_NUMBER = env.GERRIT_CHANGE_NUMBER //"76775"
        echo "GERRIT_PROJECT is $GERRIT_PROJECT, GERRIT_CHANGE_NUMBER is $GERRIT_CHANGE_NUMBER"

        List changedFiles = getChangedFiles(GERRIT_CHANGE_NUMBER)
        echo "changedFiles is $changedFiles"
        List libFiles = getLibFiles(changedFiles)
        echo "libFiles is $libFiles"

        if(libFiles){
            currentBuild.description = "This change have lib file."
            if (projectInWhiteList(GERRIT_PROJECT)) {
                Boolean verifyPlus1 = true
                List    excepFiles = []
                libFiles.each{String libFile ->
                        if (!fileInWhiteList(GERRIT_PROJECT,libFile)){
                            verifyPlus1 = false
                            excepFiles.add(libFile)
                        }
                }
                if (verifyPlus1){
                    echo "All lib files in white list."
                    return ["result":true, "info":"All lib files in white list."]
                }else{
                    echo "${excepFiles.join(',')} is not exist in White list,please check it."
                    String msg = "${excepFiles.join(',')} is not exist in White list,please check it."
                    return ["result":false, "info":"$msg"]
                }

            }else{
               echo "$GERRIT_PROJECT not exist in White.list, but change have lib files,please check it."
               return ["result":false, "info":"$GERRIT_PROJECT not exist in White.list, but change have lib files,please check it."]
            }
        }else{
            echo "Change files don't contain .a, .so , skip check."
            return ["result":true, "info":"Check whiteList success!"]
        }
}

String getBugStatus(String bugID){
    String status = ""
    String  bugInfo = sh( returnStdout: true, script:"""#!/bin/bash -x
        curl -q --config /home/scm/.ssh/redmine.config  "http://10.0.7.8:3000/issues.json?issue_id=$bugID&status_id=*"
    """).trim()
    def info =new JsonSlurper().parseText(bugInfo)
    status = info.issues.status.id.toString()
    return status
}

Boolean isClosedBug(String bugID){
    String status = getBugStatus(bugID)
    if(status in ["[5]","[6]","[7]"] || status == "[]"){
        return true
    }else{
        return false
    }
}

Boolean haveClosedBugID(List bugIDs){
    Boolean haveClosedBug = false
    bugIDs.each{ String bugID ->
        if(isClosedBug(bugID)){
            haveClosedBug = true
        }
    }
    return haveClosedBug
}

Map checkRedmineID(){
    List bugIDs = []
    bugIDs = getRedMineId()
    echo "bugIDs is $bugIDs "
    if(haveClosedBugID(bugIDs)){
        echo "Fail,have closed bug id, please check."
        return ["result":false, "info":"Check bug ID failed, because msg have closed bug."]
    }else{
        echo "Success,not have closed bug ID."
        return ["result":true, "info":"Check bug ID success."]
    }
}

String getNoteInfo(){
    if(!env.GERRIT_CHANGE_SUBJECT.contains("Revert")){
        return """
            {"issue":{"notes":"Fixed in http://10.0.7.214:8081/#/c/$env.GERRIT_CHANGE_NUMBER/"}}
        """}else {
        return """
            {"issue":{"notes":"Change was reverted in http://10.0.7.214:8081/#/c/$env.GERRIT_CHANGE_NUMBER/"}}
        """
    }
}

def postGerritChangeToRedmine(List bugIDs){
    String noteInfo = getNoteInfo()
    writeFile file: "/tmp/note_${env.BUILD_NUMBER}", text: noteInfo
    bugIDs.each{String bugID ->
        sh(returnStatus: true, script:"""#!/bin/bash -x
            curl --config /home/scm/.ssh/redmine.config  -H "Content-Type:application/json" -X PUT --data @/tmp/note_${env.BUILD_NUMBER}  http://10.0.7.8:3000/issues/${bugID}.json
        """)
    }
}

List getRedMineId(){
    String bugIDs = ""
    if(env.GERRIT_CHANGE_SUBJECT =~ /#[0-9]{5}/){
        bugIDs = env.GERRIT_CHANGE_SUBJECT.split("]").first().split("#").last()
        return bugIDs.split(',')
    }else{
        return []
    }
}

def postToRedmine(){
    List bugIDs = []
    bugIDs = getRedMineId()
    echo "bugIDs is $bugIDs "
    postGerritChangeToRedmine(bugIDs)
}

timestamps{
    node("Linux_Build"){

        if(!env.GERRIT_EVENT_TYPE.equals("change-merged")){
            Map resultW = checkWhiteList()
            Map resultR = checkRedmineID()
            if(resultW.result && resultR.result){
                echo "Check whiteList and Redmine both success."
                codeVerify("+1","Check whiteList and bug ID both success.", env.GERRIT_CHANGE_NUMBER, env.GERRIT_PATCHSET_NUMBER)
            }else{
                echo "Check whiteList and Redmine failed."
                codeVerify("-1","SCM check fail. Details:${resultW.info} ${resultR.info}", env.GERRIT_CHANGE_NUMBER, env.GERRIT_PATCHSET_NUMBER)
                currentBuild.description = "Check whiteList and bugID failed. Verified -1"
                currentBuild.result = 'UNSTABLE'
            }
        }else{
           postToRedmine()
        }
    }
}
