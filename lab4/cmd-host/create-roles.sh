#!/bin/bash

iamOutput=$(aws iam create-role --role-name CodeDeploy-L`date +%s`-ec2-service-role --assume-role-policy-document file:////home/ec2-user/EC2Trust.txt --query 'Role.[RoleName,Arn]' --output text)
ec2RoleName=$(echo $iamOutput | cut -d' ' -f 1)
ec2RoleARN=$(echo $iamOutput | cut -d' ' -f 2)
aws iam put-role-policy --role-name $ec2RoleName --policy-name CodeDeploy-Role-EC2 --policy-document file:////home/ec2-user/EC2InstancePolicy.txt
aws iam create-instance-profile --instance-profile-name CodeDeploy-EC2
aws iam add-role-to-instance-profile --instance-profile-name CodeDeploy-EC2 --role-name $ec2RoleName

iamOutput=$(aws iam create-role --role-name CodeDeploy-L`date +%s`-code-deploy-role --assume-role-policy-document file:////home/ec2-user/CodeDeployTrustPolicy.txt --query 'Role.[RoleName,Arn]' --output text)

deployRoleName=$(echo $iamOutput | cut -d' ' -f 1)
deployRoleARN=$(echo $iamOutput | cut -d' ' -f 2)

aws iam put-role-policy --role-name $deployRoleName --policy-name CodeDeploy-Role-EC2 --policy-document file:////home/ec2-user/CodeDeployTrustRole.txt

echo "ec2-service-role-arn:		 $ec2RoleARN"
echo
echo "code-deploy-role-arn:	 $deployRoleARN"
echo
