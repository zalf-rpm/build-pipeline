pipeline {
  agent none
  parameters {
    choice(choices: ['PATCH', 'MINOR', 'MAYOR', 'NONE'], 
    description: '''increase semanic version number (<mayor>.<minor>.<patch>) (1.2.34)
- increment patch version if backwards compatible big fixes are introduced
- increment minor version if new backwards compatible functionality is introduced to the public API
- increment major version if any backwards incompatible changes are introduced to the public API''', 
      name: 'INCREASE_VERSION')
    booleanParam(defaultValue: true, 
      description: 'cleanup workspace and do a clean build', 
      name: 'CLEAN_WORKSPACE')
  }
  stages {   
      stage('parallel stage') {
        parallel {
            stage('BuildLinux') {
            // build it on a debian linux node 
            agent { label 'debian' }
            steps {
                // git checkout and optional cleanup
                doGitCheckout(params.CLEAN_WORKSPACE)
                script {
                    if ( !fileExists('boost') )
                    {
                        def returnValueSymlink = sh returnStatus: true, script: 'ln -s ../../boost boost '
                        if (returnValueSymlink != 0)
                        {
                            currentBuild.result = 'FAILURE'
                        }
                    }
                }
                // create cmake project in folder _cmake_linux
                script {
                    sh returnStatus: true, script: 'mkdir -p _cmake_linux'
                    dir('_cmake_linux')
                    {
                        def returnValueCmake = sh returnStatus: true, script: 'cmake ../monica'
                        if (returnValueCmake != 0)
                        {
                            currentBuild.result = 'FAILURE'
                        }
                    }
                }
                // compile project
                script {
                    dir('_cmake_linux')
                    {
                        def returnValueMake = sh returnStatus: true, script: 'make'
                        if (returnValueMake != 0)
                        {
                            currentBuild.result = 'FAILURE'
                        }
                    }
                }
            }
            }
    
            stage('BuildWindows') {
            agent { label 'windows' }
            steps {
                doGitCheckout(params.CLEAN_WORKSPACE)
                script {
                    if ( !fileExists('boost') )
                    {
                        def returnValueSymlink = bat returnStatus: true, script: 'if exist boost ( echo \"boost link already exist \" ) else (  mklink /D boost ..\\..\\boost )'
                        if (returnValueSymlink != 0)
                        {
                            currentBuild.result = 'FAILURE'
                        }
                    }
                }
                // compile project
                script {
                    dir('monica') {
                    bat script: '''if not exist _cmake_win32 mkdir _cmake_win32
                                    cd _cmake_win32
                                    cmake -G "Visual Studio 15" ..
                                    cd ..'''
                    }
                    def returnValueBuild = bat returnStatus: true, script: 'msbuild monica/_cmake_win32/monica.sln /p:Configuration=Release /p:Platform=\"Win32\"'
                    if (returnValueBuild != 0)
                    {
                        currentBuild.result = 'FAILURE'
                    }
                }
            }
            }
      }
    }
  }
}

def doGitCheckout(cleanWorkspace) {
  // cleanup workspace
  if (cleanWorkspace)
  {
    deleteDir()
  }
  // Get code from a GitHub repository
  checkout([$class: 'GitSCM', branches: [[name: '*/master']], 
    doGenerateSubmoduleConfigurations: false, 
    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'monica']], 
    submoduleCfg: [], 
    userRemoteConfigs: [[url: 'https://github.com/zalf-rpm/monica.git']]])
  checkout([$class: 'GitSCM', branches: [[name: '*/master']], 
    doGenerateSubmoduleConfigurations: false, 
    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'util']], 
    submoduleCfg: [], 
    userRemoteConfigs: [[url: 'https://github.com/zalf-rpm/util.git']]])
  checkout([$class: 'GitSCM', branches: [[name: '*/master']], 
    doGenerateSubmoduleConfigurations: false, 
    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'sys-libs']], 
    submoduleCfg: [], 
    userRemoteConfigs: [[url: 'https://github.com/zalf-rpm/sys-libs']]])
}