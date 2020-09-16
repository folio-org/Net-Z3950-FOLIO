@Library ('folio_jenkins_shared_libs') _

pipeline {

  environment {
    BUILD_DIR = "${env.WORKSPACE}"
    modDescriptor = 'ModuleDescriptor.json'
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

            def mdJson = readJSON(file: env.modDescriptor)
            def modId = mdJson.id
            env.name = sh(returnStdout: true, 
                 script: "echo ${name} | cut -d '-' -f -2").trim()
            env.bare_version = sh(returnStdout: true, 
                 script: "echo ${name} | cut -d '-' -f 3-").trim()
        
            // if release 
            if ( foliociLib.isRelease() ) {
              env.isRelease = true 
              env.dockerRepo = 'folioorg'
              env.version = env.bare_version
            }
            else {
              env.dockerRepo = 'folioci'
              env.version = "${env.bare_version}-SNAPSHOT.${env.BUILD_NUMBER}"
            }
          }
        }
        sendNotifications 'STARTED'  
      }
    }
    
    stage('Build Docker') {
      steps {
        script {
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

    stage('Publish Module Descriptor') {
      when {
        anyOf { 
          branch 'master'
          expression { return env.isRelease }
        }
      }
      steps {
        script {
          def foliociLib = new org.folio.foliociCommands()
          foliociLib.updateModDescriptor(env.modDescriptor) 
        }
        postModuleDescriptor(env.modDescriptor)
      }
    }

  } // end stages

  post {
    always {
      dockerCleanup()
      sendNotifications currentBuild.result 
    }
  }
}
  
