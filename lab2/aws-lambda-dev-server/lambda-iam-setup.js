var AWS = require('aws-sdk');
var fs = require('fs');

var roleName = "LambdaCustomResourceExecutionPolicy";

// Get the trust policy that allows both AWS Lambda and our user to assume the role required to execute our function.
var trustPolicy = fs.readFileSync('lambda-trust-rel.json', 'utf8').trim();

var iam = new AWS.IAM({});

var lambdaRoleArn = null;
var params = {
	RoleName : roleName,
	AssumeRolePolicyDocument : trustPolicy
}

// Create the role that we will use to invoke the Lambda function, and pass in the
// policy that grants permissions to assume this role.
iam.createRole(params, function(err, data) {
	if (err) {
		console.log("ERROR: Role not created.");
		console.log(err);
		return;
	} else {
		console.log("IAM role for AWS Lambda function created");
		// Append the default AWS Lambda policy document to this role.
		var rolePolicyParams = {
			PolicyArn : "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
			RoleName : roleName
		}
		iam.attachRolePolicy(rolePolicyParams, function(err, data2) {
			if (err) {
				console.log("Error in attachRolePolicy");
				console.log(err);
			} else {
				console.log("Basic AWS Lambda policy (CloudWatch Logs access right only) added to our role");
			  console.log("\nRole ARN created: " + data.Role.Arn)
			}
		});
	}
});
