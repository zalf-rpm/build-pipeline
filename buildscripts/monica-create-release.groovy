pipeline {
    agent none
    stages {  
        stage('test stage') {
            agent { label 'debian' }  
            environment {
                baseurl = "https://api.github.com"
                owner = "zalf-rpm"
                repository = "monica"
                extract_path = "artifact"
                artifact_path = "$extract_path/monica/installer"
            }
            steps {
                // script
                // {
                //     def response = httpRequest (
                //                     httpMode: 'GET',
                //                     url:"$env.baseurl/repos/$env.owner/$env.repository/releases/latest",
                //                     authentication: 'zalffpmbuild_basic')
                //     print (response.content)

                // }

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

                        // send git REST api request to create a release
                        def uploadURL = createRelease(env.baseurl, env.owner, env.repository, 'zalffpmbuild_basic', tag, releaseName, "TODO")
                        if (uploadURL != "none")
                        {
                            // remove parameter description
                            uploadURL = uploadURL - ~/\{.*\}/
                            for (asset in uploadFileNames)
                            {
                                // upload asset file
                                uploadReleaseAsset(uploadURL, 'zalffpmbuild_basic', asset)                                
                            }
                        }
                    }
                }
            }
        }
    }
}

def createRelease(baseurl, owner, repository, credentials, tag, releaseName, releaseDescription)
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
                    url:"$baseurl/repos/$owner/$repository/releases",
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
