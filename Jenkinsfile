pipeline {
    agent any

    options {
        skipDefaultCheckout()
    }

    environment {
        IMAGE_NAME     = 'portfolio'
        CONTAINER_NAME = 'portfolio'
        HOST_PORT      = '8081'
    }

    stages {
        stage('Clone') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh 'docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} -t ${IMAGE_NAME}:latest .'
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'portfolio-basic-auth',
                    usernameVariable: 'BASIC_AUTH_USER',
                    passwordVariable: 'BASIC_AUTH_PASS'
                )]) {
                    sh '''
                        docker rm -f ${CONTAINER_NAME} || true
                        docker run -d \
                          --name ${CONTAINER_NAME} \
                          --restart unless-stopped \
                          -p ${HOST_PORT}:80 \
                          -e APP_ENV=prod \
                          -e BASIC_AUTH_USER \
                          -e BASIC_AUTH_PASS \
                          ${IMAGE_NAME}:${BUILD_NUMBER}
                    '''
                }
            }
        }
    }
}