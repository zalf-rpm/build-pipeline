pipeline {
    agent none
    stages {  
        stage('test stage') {
            agent { label 'debian' }  
            environment {
                apiUrl = "https://api.github.com"
                baseUrl = "https://github.com"
                owner = "zalf-rpm"
                repository = "monica"
                extract_path = "artifact"
                artifact_path = "$extract_path/monica/installer"
                credentials = 'zalffpmbuild_basic'
            }
            steps {
                // copy artifacts from another job
                // create artifact path 
                sh "rm -rf $env.extract_path"
                sh "mkdir -p $env.extract_path"
                // copy artifact step
                step ([$class: 'CopyArtifact',
                        projectName: 'monica.pipeline',
                        filter: "monica/installer/MONICA-Setup-*.exe",
                        target: env.extract_path]);

                script {

                    dir("$env.artifact_path")
                    {
                        def version = "1.1.1"
                        def buildNr = "123"
                        def uploadFileNames = []
                        files = findFiles(glob: 'MONICA-Setup-*.exe')
                        for (file in files)
                        {
                            print ("file to upload: $file")
                            uploadFileNames << (file.name)
                            // extract version and build number from installer filename
                            if (file.name ==~ /MONICA-Setup-.*-x64-64bit-build.*.exe/)
                            {
                                buildNr = file.name - ~"MONICA-Setup-.*-x64-64bit-build"
                                buildNr = buildNr - ~".exe" 
                                version = file.name - ~"MONICA-Setup-"
                                version = version - ~"-x64-64bit-build.*.exe"
                            }
                        }
                        // release tag
                        def tag = version + "." + buildNr
                        // release name
                        def releaseName = "MONICA $version"
                        print("TAG:" + tag)
                        print("Release Name:" + releaseName)
                        print ("upload files" + uploadFileNames)

                        // extract git commit log starting from last release tag
                        def log = extractLog(env.apiUrl, env.owner, env.repository, env.baseUrl, env.credentials)
                        log = log.replace("\r\n", "<br/>")
                        log = log.replace("\n", "<br/>")
                        // send git REST api request to create a release
                        def uploadURL = createRelease(env.apiUrl, env.owner, env.repository, env.credentials, tag, releaseName, log)
                        if (uploadURL != "none")
                        {
                            // remove parameter description
                            uploadURL = uploadURL - ~/\{.*\}/
                            for (asset in uploadFileNames)
                            {
                                // upload asset file
                                uploadReleaseAsset(uploadURL, env.credentials, asset)                                
                            }
                        }
                    }
                }
            }
        }
    }
}

def createRelease(apiUrl, owner, repository, credentials, tag, releaseName, releaseDescription)
{

    postContent =  """{
        "tag_name": "${tag}",
        "target_commitish": "master",
        "name": "${releaseName}",
        "body": "${releaseDescription}",
        "draft": true,
        "prerelease": false
    }"""
    print (postContent)

    response = httpRequest (
                    httpMode: 'POST',
                    url:"$apiUrl/repos/$owner/$repository/releases",
                    authentication: credentials, 
                    contentType: 'APPLICATION_JSON', 
                    requestBody: postContent
                    )
    

    if (response.status == 201)
    {
        print (response.content)
        props = readJSON text: response.content  
        // extract upload url for assets
        return props['upload_url']
    }
    else
    {
        return "none"
    }
}

def uploadReleaseAsset(uploadURL, credentials, assetName)
{
    withCredentials ([usernamePassword(credentialsId: credentials, passwordVariable: 'password', usernameVariable: 'username')])
    {
        def upload_url = "$uploadURL?name=$assetName"
        def filename = "./" + assetName
        def returnVal = sh  returnStatus: true, 
                           script: """curl -i --data-binary @"$filename" -H "Content-Type: application/octet-stream" $upload_url -u $username:$password """
    }
}    

// apiUrl -> https://api.github.com
// repoOwner -> zalf-rpm
// repository -> monica
// baseUrl -> https://github.com/
def extractLog(apiUrl, repoOwner, repository, baseUrl, credentials)
{
    if ( fileExists("${repository}.git") ) {
        dir("${repository}.git") {
            deleteDir()
        }
    }
    // get latest release
    def response = httpRequest (
                    httpMode: 'GET',
                    url:"$apiUrl/repos/$repoOwner/$repository/releases/latest",
                    authentication: credentials)
    print (response.content)
    props = readJSON text: response.content  
    def oldTag = props['tag_name']


    // clone only version control informations, no files
    def bareClone = "git clone --bare $baseUrl/$repoOwner/$repository"

    // get log from tag to head, '%s' just the subject 
    def getLog = "git log ${oldTag}.. --format=%s"
    def out = ""
    if (isUnix())
    {
        sh bareClone                           
        dir("${repository}.git")
        {
            out = sh returnStdout: true, script: getLog                            
        }
    }
    else
    {
        bat bareClone
        dir("${repository}.git")
        {
            out = bat returnStdout: true, script: getLog                            
        }
    }
    print (out)
    return out
}