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
                        // create vcpkg package directory 
                        doVcpkgCheckout()   
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
                        // create cmake project in folder monica/_cmake_linux
                        script {
                            dir('monica')
                            {
                                sh returnStatus: true, script: 'sh update_linux.sh'
                            }
                        }
                        // compile project
                        script {
                            dir('monica/_cmake_linux')
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
                // build on windows node
                stage('BuildWindows') {
                    agent { label 'windows' }
                    steps {
                        // git checkout and optional cleanup
                        doGitCheckout(params.CLEAN_WORKSPACE)
                        // create vcpkg package directory 
                        doVcpkgCheckout()               
                        script {
                            if ( !fileExists('boost') )
                            {
                                // create symlink to boost
                                def returnValueSymlink = bat returnStatus: true, script: 'if exist boost ( echo \"boost link already exist \" ) else (  mklink /D boost ..\\..\\boost )'
                                if (returnValueSymlink != 0)
                                {
                                    currentBuild.result = 'FAILURE'
                                }
                            }
                        }
                        // create cmake project in folder monica/_cmake_win32 and monica/_cmake_win64
                        script {
                            dir('monica')
                            {
                                bat returnStatus: true, script: 'call update_solution.cmd'
                                bat returnStatus: true, script: 'call update_solution_x64.cmd'
                            }
                        }
                        // compile project
                        script {
                            dir('monica') {
                                def returnValueBuild32 = bat returnStatus: true, script: 'msbuild _cmake_win32/monica.sln /p:Configuration=Release /p:Platform=\"Win32\"'
                                def returnValueBuild64 = bat returnStatus: true, script: 'msbuild _cmake_win64/monica.sln /p:Configuration=Release /p:Platform=\"x64\"'
                                if (returnValueBuild32 != 0 || returnValueBuild64 != 0)
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
    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'build-pipeline']], 
    submoduleCfg: [], 
    userRemoteConfigs: [[url: 'https://github.com/zalf-rpm/build-pipeline.git']]])
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

def doVcpkgCheckout()
{
    if (isUnix())
    {
        dir('build-pipeline/buildscripts') {
            sh returnStatus: true, script: 'sh ./linux-prepare-vcpkg.sh'
        }
    }
    else
    {
        dir('build-pipeline/buildscripts') {
            bat returnStatus:true, script: 'call window-prepare-vcpkg.bat'
        }
    }
}