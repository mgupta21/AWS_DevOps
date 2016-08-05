#!/bin/bash +ex
source /var/lib/jenkins/.env_config

#If this is the first run, do nothing
if [ -z "$RUNONCE" ]; then
    echo "export RUNONCE=true" >> /var/lib/jenkins/.env_config
    exit 0
fi

CUR_SHA=$(git rev-parse refs/remotes/origin/master^{commit})

echo 
echo Current hash: $CUR_SHA

gitDiff=($(git show --pretty="format:" --name-only $CUR_SHA))

echo "=========================================="
echo
echo "What Changed?"
echo
    for i in "${gitDiff[@]}"
    do
	echo "filename: $i"
	[ "${i##*.}" == "php" ] && codeChange="true"
    done
echo
echo
echo "========================================="

  if [ ! -z "$gitDiff" ]; then
    echo 
    checkPaths=("cfn/*" "php/*")
    for dir in "${checkPaths[@]}"
    do
      for f in $dir
      do
        if [[ "$f" == "cfn/"* && "${f##*.}" == "php" ]]; then
          echo $f
          echo "You have placed a PHP file in the CloudFormation directory.  Please move it to the PHP directory."
        elif [[ "$f" == "cfn/"* && "${f##*.}" != "php" ]]; then
          echo
          echo "Checking CloudFormation template for validity: $f..." && sleep 2
          cfnVerify=$(aws cloudformation validate-template --template-body file://$f --region $REGION 2>&1 | grep ValidationError)
          [ -z "$cfnVerify" ] && echo "No errors found! - $cfnVerify" && sleep 2
          [ ! -z "$cfnVerify" ] && echo "Errors found:" && echo $cfnVerify \
                && echo && failBuild="true" && badFiles+=("$f\n")
        elif [[ "$f" == "php/"* && "${f##*.}" == "php" ]]; then
          echo
          echo "Checking PHP File: $f" && sleep 2
          phpVerify=$(php -l $f 2>&1 | grep "PHP Parse error")
          [ -z "$phpVerify" ] && echo "No errors found!" && sleep 2 && buildDeploy="true"
          [ ! -z "$phpVerify" ] && echo "Errors found:" && echo $phpVerify \
                && echo  && failBuild="true" && badFiles+=("$f\n")
        elif [[ "$f" == "php/"* && "${i##*.}" == "template" ]]; then
          echo "This is likely a CloudFormation template...are you sure its in the correct directory?"
          echo
        else
          echo "Skipping file with extension ${f##*.}"
          echo
        fi
      done
    done
  else
    echo "No artifacts have changed since the previous build.  Have a nice day!"
  fi

if  [ "$failBuild" == "true" ]; then
  echo "Encountered errors.  Cannot deploy latest build." \
  && echo "Please correct errors in the following file(s):" && echo -e "$badFiles"
else
  if [[ "$buildDeploy" == "true" && "$codeChange" == "true" ]]; then
    if [ -f "cfn/lab-3-app-test-env.template" ]; then
	echo "PHP code looks good and our CloudFormation test template is in place.  Lets go!"
    else
	echo "Although our PHP code looks good, the Cloudformation test template cannot be found."
	echo
	echo "Please ensure the following exists in your Git repository:"
	echo
	echo "cfn/lab-3-app-test-env.template"
	exit 1
    fi
    echo 
    echo "============================================================="
    echo "============================================================="
    echo
    echo "Create package with contents of /php directory and push to S3."
    buildNum=1.$(date '+%m.%H.%M')
    cd php/ && tar -zcvf ../webapp-$buildNum.tar.gz . && cd .. && echo
    aws s3 cp webapp-$buildNum.tar.gz s3://$ARTIFACT_BUCKET/builds/webapp-$buildNum.tar.gz
    rm -f webapp-$buildNum.tar.gz
    echo
    echo "Creating test environment for new application code..."
    aws cloudformation create-stack --stack-name webappTest-${buildNum//./-} \
      --template-body file://cfn/lab-3-app-test-env.template --parameters \
      ParameterKey=TestVPCCIDR,ParameterValue=10.2.0.0/16 \
      ParameterKey=TestPublicSubnetCIDR,ParameterValue=10.2.10.0/24 \
      ParameterKey=KeyName,ParameterValue=$KEYNAME \
      ParameterKey=WebInstanceEC2InstanceProfile,ParameterValue=$WEBInstanceROLE \
      ParameterKey=buildPath,ParameterValue=s3://$ARTIFACT_BUCKET/builds/webapp-$buildNum.tar.gz --capabilities CAPABILITY_IAM --region $REGION \
      --query 'CreationTime' --output text
    echo We will now wait until the stack has been created...
    sleep 15
    stackStatus=$(aws cloudformation describe-stacks --stack-name webappTest-${buildNum//./-} --region $REGION --query 'Stacks[].StackStatus' --output text)
    while [ "$stackStatus" == "CREATE_IN_PROGRESS" ]
    do
      stackStatus=$(aws cloudformation describe-stacks --stack-name webappTest-${buildNum//./-} --region $REGION --query 'Stacks[].StackStatus' --output text)
      if [ "$stackStatus" == "CREATE_IN_PROGRESS" ]; then
        echo "Stack is still being created..."
        sleep 30
      elif [ "$stackStatus" == "ROLLBACK_IN_PROGRESS" ]; then
	echo "Test environment stack failed.  Please troubleshoot and try your deployment again!"
	exit 1
      elif [ "$stackStatus" == "CREATE_COMPLETE" ]; then
        echo "Your test environment created successfully!"
        echo "View your web app: http://$(aws cloudformation describe-stacks --stack-name webappTest-${buildNum//./-} --region $REGION --query 'Stacks[].Outputs[?OutputKey==`TestWebInstanceIP`].OutputValue' --output text)"
        echo
        exit 0
      else
	echo "Unexpected stack status - $stackStatus!  Please investigate."
	exit 1
      fi
    done
    
    echo
  elif [[ "$buildDeploy" == "true" && "$codeChange" != "true" ]]; then
    echo
    echo "Validation completed successfully, however, no application code was changed.  No new deployments will be initiated at this time."
    echo
  fi
fi 

echo
echo

