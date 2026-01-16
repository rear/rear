@Library('cove')
import nable.cove.helpers.ShellHelper
import nable.cove.SecretManager

final String jobName = env.JOB_NAME.split('/')[-2]
final String branchName = env.CHANGE_TARGET ?: env.BRANCH_NAME
final boolean isProd = jobName.endsWith('-prd')
final boolean isProdBranch = branchName == 'master'
final String envType = isProd ? 'prd' : 'dev'

def String repositoryName = 'rear'

def config = [
    cloud: "backup-${envType}",
    serviceAccount: "backup",
    buildImage: "${nsbuild.ecrHost()}/cove/onprem/develop/rear-builder:v1.7"
]

def secrets = [
    jenkins: [
        'github-app': [
            usernamePassword: [
                usernameVariable: 'GITHUB_USERNAME',
                passwordVariable: 'GITHUB_PASSWORD'
            ]
        ]
    ],
    kubernetes: [
        'artifactory': [
            'JFROG_USERNAME': 'ARTIFACTORY_USERNAME_COVE',
            'JFROG_ACCESS_TOKEN': 'ARTIFACTORY_TOKEN_COVE'
        ]
    ]
]

def secretManager
def shellHelper
def shouldBuild = true

pipeline {
    agent {
        kubernetes {
            cloud "${config.cloud}"
            yaml nsbuild.agentYaml(config)
            defaultContainer nsbuild.defaultContainer(config)
        }
    }

    options {
        ansiColor('xterm')
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    if (isProd != isProdBranch) {
                        echo "Environment mismatch: target branch is ${branchName}, job is ${jobName}. Skipping build."
                        shouldBuild = false
                    } else {
                        echo "Environment match: target branch is ${branchName}, job is ${jobName}. Proceeding with build."
                    }

                    secretManager = new SecretManager(
                        this,
                        envType,
                        jenkinsWhitelist: [
                            'github-app'
                        ],
                        k8sWhitelist: [
                            'artifactory'
                        ]
                    )
                    shellHelper = new ShellHelper(this, isUnix: true)
                }
            }
        }
        stage('Load secrets') {
            when {
                expression { shouldBuild }
            }
            agent {
                kubernetes {
                    cloud "${config.cloud}"
                    yaml secretManager.getK8sPodYaml(secrets)
                    defaultContainer 'secrets'
                    customWorkspace 'w'
                }
            }
            steps {
                script {
                    secretManager.loadJenkinsSecrets(secrets.jenkins)
                    secretManager.loadK8sSecrets(secrets.kubernetes, shellHelper)
                }
            }
        }
        stage('Build') {
            when {
                expression { shouldBuild }
            }
            environment {
                ARTIFACTORY_URL = 'https://mspsolarwinds.jfrog.io/artifactory'
            }
            steps {
                script {
                    secretManager.withSecrets {
                        shellHelper.exec('Validate', """
                            make validate
                        """)
                        shellHelper.exec('Run unit tests', """
                            make test-cove
                        """)
                        shellHelper.exec('Build', """
                            make dist
                        """)
                        def repository = (envType == 'dev') ? 'cove-generic-develop-local' : 'cove-generic-release-local'
                        shellHelper.exec('Upload', """
                            PACKAGE="rear-\$(make version).tar.gz"
                            curl -sSf -X PUT -T dist/\${PACKAGE} \
                                -u \${ARTIFACTORY_USERNAME_COVE}:\${ARTIFACTORY_TOKEN_COVE} \
                                \${ARTIFACTORY_URL}/${repository}/rear/\${PACKAGE}
                        """)
                    }
                }
            }
        }
    }
}
