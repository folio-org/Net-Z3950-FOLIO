@Library ('folio_jenkins_shared_libs') _

pipeline {

  environment {
    BUILD_DIR = "${env.WORKSPACE}"
  }

  options {
    timeout(30)
    buildDiscarder(logRotator(numToKeepStr: '30'))
  }

  agent {
    node {
      label 'jenkins-agent-java11'
    }
  }

  stages {
    stage ('Setup') {
      steps {
        dir(env.BUILD_DIR) {
          script {
            def foliociLib = new org.folio.foliociCommands()

            // there's an MD coming at some point so temp for testing
            env.name = 'z2folio'
            env.z2folioversion = '0.0.1'
        
            // if release 
            if ( foliociLib.isRelease() ) {
              env.isRelease = true 
              env.dockerRepo = 'folioorg'
              env.version = env.z2folioversion
            }
            else {
              env.dockerRepo = 'folioci'
              env.version = "${env.z2folioversion}-SNAPSHOT.${env.BUILD_NUMBER}"
            }
          }
        }
        sendNotifications 'STARTED'  
      }
    }

    stage('Build') { 
      steps {
        dir(env.BUILD_DIR) {
          sh "perl Makefile.PL"
          sh "make"
          sh "make test"
          sh "sudo make install"
        }
      }
    }
   
    stage('Build Docker') {
      steps {
        script = {
          buildDocker {
            publishMaster = 'yes'
            healthChk = 'no'
          }
        }
      } 
    }

    stage('Publish Docker Image') { 
      when { 
        anyOf {
          branch 'master'
          expression { return env.isRelease }
        }
      }
      steps {
        script {
          docker.withRegistry('https://index.docker.io/v1/', 'DockerHubIDJenkins') {
            sh "docker tag ${env.dockerRepo}/${env.name}:${env.version} ${env.dockerRepo}/${env.name}:latest"
            sh "docker push ${env.dockerRepo}/${env.name}:${env.version}"
            sh "docker push ${env.dockerRepo}/${env.name}:latest"
          }
        }
      }
    }

    // no md yet
    //stage('Publish Module Descriptor') {
    //  when {
    //    anyOf { 
    //      branch 'master'
    //      expression { return env.isRelease }
    //    }
    //  }
    //  steps {
    //    script {
    //      def foliociLib = new org.folio.foliociCommands()
    //      foliociLib.updateModDescriptor(env.MD) 
    //    }
    //    postModuleDescriptor(env.MD)
    //  }
    //}

  } // end stages

  post {
    always {
      dockerCleanup()
      sendNotifications currentBuild.result 
    }
  }
}
  
