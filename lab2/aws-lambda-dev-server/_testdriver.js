/*

 Modified version of the test harness produced by the AWS Toolkit for Visual Studio. Modified to include the ability to assume a role, so that the test harness can execute with the same permissions that the Lambda function will have when published to AWS.

 */

var fs = require('fs');
var AWS = require('aws-sdk');

// Assume the Lambda role for our test harness.
var sts = new AWS.STS({});

var functionName = process.argv[2];
if (!functionName) {
	console.log("No functionName specified as an argument. Specify the name of the file (without the .js suffix) to load in order to test.");
	return;
}

var app = null;
try {
	app = require('./' + functionName);
} catch (e) {
	console.log("Error loading ./" + functionName + ".js - " + e.message);
	return;
}

var roleArn = process.argv[3];
if (!roleArn) {
	console.log("No RoleARN specified as an argument. The argument to this harness must be an IAM role that \
the user can assume that will grant the locally running function the same permissions as the function will have \
when published to AWS Lambda.\n");

	return;
}

var params = {
	RoleArn: roleArn,
	RoleSessionName: "LambdaCfnVerifierTest"
}

sts.assumeRole(params, function(err, data) {
	if (err) {
		console.log(err, err.stack);
		return;
	} else {
	   console.log("Assumed role to test AWS Lambda function " + functionName + "\n");
		  // console.log(data);

      // Pass temporary credentials in to Lambda.
		  console.log("Starting AWS Lambda function...\n");
      AWS.config.update({
		      accessKeyId: data.AccessKey,
		      secretAccessKey: data.SecretAccessKey
		});

		var event = JSON.parse(fs.readFileSync('_sampleEvent.json', 'utf8').trim());

		var context = {};
		context.done = function () {
		    console.log("Lambda Function Complete");
		}

		app.handler(event, context);
	}
});
