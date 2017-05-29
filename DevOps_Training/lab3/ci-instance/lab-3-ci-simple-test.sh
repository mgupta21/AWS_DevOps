#!/bin/bash +ex
source /var/lib/jenkins/.env_config

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
          [ -z "$phpVerify" ] && echo "No errors found!" && sleep 2
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
  echo 
  echo "========================================="
  echo
  echo "Encountered errors!!  Please correct errors in the following file(s):" && echo -e "$badFiles" && exit 1
else
  echo "Everything looks good!!  You should be ready to merge with the master branch." && sleep 2
fi


