param (
[string] $region = "us-west-2"
)

import-module "C:\Program Files (x86)\AWS Tools\PowerShell\AWSPowerShell\AWSPowerShell.psd1"

$roleName = "LambdaCustomResourceExecutionPolicy3"
$policyArn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
Set-DefaultAWSRegion($region)

# Get the trust policy that allows both AWS Lambda and our user to assume the role required to execute our function.
$trustPolicy = get-content "C:\temp\cfnverifierlambda-net\lambda-trust-rel.json" -raw

try {
  $role = New-IAMRole -RoleName $roleName -AssumeRolePolicyDocument $trustPolicy
} catch {
  write-error("Could not create role: " + $_)
  exit;
}
$roleArn = $role.Arn;

write-host "IAM role for AWS Lambda function created"

try {
  $rolePolicy = Register-IAMRolePolicy -RoleName $roleName -PolicyArn $policyArn
} catch {
    write-error("Could not register role policy: " + $_)
    exit;
}

write-host "Basic AWS Lambda policy (CloudWatch Logs access right only) added to our role."
write-host("Role ARN created: " + $roleArn)
