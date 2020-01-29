#!/bin/bash
aws ec2 create-security-group --group-name fargate-web-app --description fargate-web-app
aws ec2 authorize-security-group-ingress --group-name fargate-web-app --protocol tcp --port 3000 --cidr 0.0.0.0/0
security_group=$(aws ec2 describe-security-groups --group-name fargate-web-app --query 'SecurityGroups[].{Name:GroupId}' --output=text)
fargatecli service create --port http:3000 fargate-web-app --security-group-id $security_group
