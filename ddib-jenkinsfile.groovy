def githubCredentialsID = env.DEFAULT_GITHUB_CREDENTIALS_ID
def gitUrl = "https://github.com/" + env.DEFAULT_ORG + "/ddib-deployment.git"
def PowerShell(psCmd) {
    psCmd=psCmd.replaceAll("%", "%%")
    bat "powershell.exe -NonInteractive -ExecutionPolicy Bypass -Command \"\$ErrorActionPreference='Stop';[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;$psCmd;EXIT \$global:LastExitCode\""
}

pipeline {
    agent any
    parameters {
		choice(
            choices: 
            [
                'Branch', 
                'Commit'
            ],
            description: 'branch or commit to build from', 
            name: 'Build_From'
        )
		string(
            description: 'Branch name for branch or commit id for commit', 
            name: 'Build_Identity',
			defaultValue: 'main',
			trim: true
        )
    }
    stages {
        stage('Git Checkout Branch') {
            when {
                expression { params.Build_From == 'Branch' }
            }
            steps {
				script {
					if (params.Build_Identity == '') {
						currentBuild.result = 'ABORTED'
						error("Build failed because of null Build_Identity.")
					}
				}
				
                git url: "${gitUrl}", branch: "${params.Build_Identity}", credentialsId: "${githubCredentialsID}"
				
				script {
					commitID = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
					branch = "${params.Build_Identity}"
				}
            }
        }
        stage('Git Checkout Commit') {
            when {
                expression { params.Build_From == 'Commit' }
            }
            steps {
				script {
					if (params.Build_Identity == '') {
						currentBuild.result = 'ABORTED'
						error("Build failed because of null Build_Identity.")
					}
				}
				
                git url: "$gitUrl", credentialsId: "${githubCredentialsID}" 
                sh "git checkout " + "${params.Build_Identity}"
				
				script {
					commitID = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
					branch = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
				}
            }
        }
        stage ('Call Powershell Script') {

            node ('windows') {
                 PowerShell(". '.\\ddib-deployment.ps1'") 
            }

        }
