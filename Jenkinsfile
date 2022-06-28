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

            // create md
            sh('./descriptors/transform-descriptor.pl descriptors/ModuleDescriptor-template.json > ModuleDescriptor.json')

            def mdJson = readJSON(file: env.modDescriptor)
            def modId = mdJson.id
            env.name = sh(returnStdout: true,
                 script: "echo ${modId} | cut -d '-' -f -2").trim()
            env.bare_version = sh(returnStdout: true,
                 script: "echo ${modId} | cut -d '-' -f 3-").trim()

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

