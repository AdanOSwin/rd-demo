pipeline {
    agent any
    stages {
        stage('First stage') {
            steps {
                sh "terraform init"
                //sh "terraform destroy"
                //sh 'terraform plan -out=demo.plan'
                //sh 'terraform apply demo.plan'
            }
        }
        stage('second stage') {
            steps {
                sh "terraform validate"
            }
        }
        stage('third stage') {
            steps {
                sh 'terraform plan -out=demo.plan'
            }
        }
        stage('Fourth stage') {
            steps {
                sh "terraform apply demo.plan"
            }
        }
    }
}

//terraform format: para acomodar codigo