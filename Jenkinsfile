pipeline {
    agent any
    stages {
        stage('First stage') {
            steps {
                echo "First stage"
                sh 'terraform plan -out=demo.plan'
                sh 'terraform apply demo.plan'
            }
        }
    }
}