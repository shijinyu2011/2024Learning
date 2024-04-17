http://192.168.50.116:722/job/testpipeline/configure:
  /*
def runproject(name,proc,cfg){
    timestamps{
        echo "start run project."
        echo "name is $name"
        proc(cfg)
        echo "end run project."
        
    }
    
}*/

def main(ndsmgr,Map paras){
    echo "input paras is $paras"
    name = paras.a
    ndsmgr.citest(name)
}


node("manager3"){
    echo "hello ,groovy"
    
    Map paras = ['a':'11','b':'22']
    def sjyndsmgr = load("/home/jenkins/workspace/test417/sjyndsmgr.groovy")
    sjyndsmgr.runproject("hello",this.&main,paras)
    
    
}


++++++++++++++++++++++++++++++++ load("sjyndsmgr.groovy")++++++++++++++++++++++++++++++++++++++++++++++++
  root@manager:/home/jenkins/workspace/test417# cat sjyndsmgr.groovy
def runproject(name,proc,cfg){
        timestamps{
                echo "start run project."
                echo "name is $name"
                proc(this,cfg)
                echo "end run project."

    }

}

def citest(name){


        echo "hello,this is citest ${name}"
}


return this
root@manager:/home/jenkins/workspace/test417# pwd
/home/jenkins/workspace/test417
root@manager:/home/jenkins/workspace/test417# ls
sjyndsmgr.groovy
root@manager:/home/jenkins/workspace/test417#
  
