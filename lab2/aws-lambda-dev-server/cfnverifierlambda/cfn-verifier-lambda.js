console.log('Loading function');

var AWS = require("aws-sdk");
var url = require("url");
var http = require("http");
var async = require("async");


var responseData = {};
responseData["PageStatus"] = new Array();

exports.handler = function (event, context) {
    console.log("REQUEST RECEIVED:\n", JSON.stringify(event) + "\n");

    if (event.RequestType == "Delete") {
        sendResponse(event, context, "SUCCESS");
        return;
    }

    var responseStatus = "FAILED";

    // Verify that we received urls.
    error = false;
    urlChecks = event.ResourceProperties.UrlChecks;
    if (!urlChecks) {
        responseData = { Error: "UrlChecks was not specified - erroring out" };
        console.log(responseData.Error);
        sendResponse(event, context, responseStatus, responseData);
    }

    async.each(urlChecks, function (item, callback) {
        http.get(item, function (res) {
            var page = {};
            page["Page"] = item;
            page["Status"] = res.statusCode;
            responseData["PageStatus"].push(page);
            console.log("Response for site " + item + ": " + res.statusCode);
            if (res.statusCode != 200) {
                console.log("Site " + item + " FAILED verification");
                error = true;
            }
            callback();
        });
    }, function (err) {
        console.log("\n");
        if (!error) {
		        console.log("All URLs passed their checks. Communicating SUCCESS back to AWS CloudFormation...\n");
            responseStatus = "SUCCESS";
        } else {
		        console.log("One or more URLs failed their checks (HTTP status code != 200). Communicating FAILED back to AWS CloudFormation -\
            expect to see stack rollback in the Management Console...\n");
	      }

        sendResponse(event, context, responseStatus, responseData);
    });
};

//Sends response to the pre-signed S3 URL
function sendResponse(event, context, responseStatus, responseData) {
    var responseBody = JSON.stringify({
        Status: responseStatus,
        Reason: "See the details in CloudWatch Log Stream: " + context.logStreamName,
        PhysicalResourceId: context.logStreamName,
        StackId: event.StackId,
        RequestId: event.RequestId,
        LogicalResourceId: event.LogicalResourceId,
        Data: responseData
    });

    console.log("RESPONSE BODY:\n", responseBody);

    var https = require("https");
    var url = require("url");

    var parsedUrl = url.parse(event.ResponseURL);
    var options = {
        hostname: parsedUrl.hostname,
        port: 443,
        path: parsedUrl.path,
        method: "PUT",
        headers: {
            "content-type": "",
            "content-length": responseBody.length
        }
    };

    var request = https.request(options, function (response) {
        console.log("STATUS: " + response.statusCode);
        console.log("HEADERS: " + JSON.stringify(response.headers) + "\n");
        // Tell AWS Lambda that the function execution is done
        context.done();
    });

    request.on("error", function (error) {
        console.log("sendResponse Error:\n", error);
        // Tell AWS Lambda that the function execution is done
        context.done();
    });

    // write data to request body
    request.write(responseBody);
    request.end();
}
