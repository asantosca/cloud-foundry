#!/bin/bash
function usage {
    cat <<EOT
NAME
     cfpush.sh -- pushes the current app to Cloud Foundry

**Usage**

For a java project, create the jar and place it in the location determined by the key "target" in your manifest.yml.

To push that jar to Cloud Foundry, simply type cfpush.sh at the command line, in the same folder in which the file manifest.yml is located.

By default cfpush.sh will push a custom app, which is the name of the current app appended with the name of the current user.
The reason for that is because the most common use case is for pushing custom apps, that need to be clearly identified by user.
If you want to push an app with a different name, use the "-a" argument

**Arguments**
The following options are available:

-a or -appname     Application name. If different than the current app.
-i or -instances   Number of instances being pushed. Default is 1.
-m or -manifest    Shows the manifest file created, but doesn't push the app to Cloud Foundry
EOT
}

if [ ! -e "manifest.yml" ]
then
    echo "The current folder doesn't contain a manifest.yml file"
    exit -1
fi


instances=1
cfpushappname=""
printManifest=false

while [ "$1" != "" ]; do
    case $1 in
        -a | --appname )        shift
                                cfpushappname=$1
                                ;;
        -i | --instances )      shift
                                instances=$1
                                ;;
        -m | --manifest )       #shift
                                printManifest=true
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

nameapp=$(grep "name" manifest.yml)
namenospages=${nameapp// /}
cfname=${namenospages:6}

if [[ -z "$cfpushappname" ]] ;
then
    cfpushappname=$cfname-$(whoami)
fi

pathapp=$(grep "path" manifest.yml)

if [[ -z "$nameapp" ]] ;
then
    echo "manifest.yml is missing the name of the app"
    exit -1
fi
if [[ -z "$pathapp" ]] ;
then
    echo "manifest.yml is missing the path of the app"
    exit -1
fi

gitBranch=$(git symbolic-ref --short -q HEAD)
date=$(date +%Y%m%d%s)
version=$(date +%y.%m)-$date-$gitBranch
manifestCF=$(mktemp CF.XXXXXXXXX)
tfile1=$(mktemp CF.XXXXXXXXX)
manifestFinal=$(mktemp CF.XXXXXXXXX)

trap "rm $manifestCF $tfile1 $manifestFinal " EXIT
cf create-app-manifest $cfname -p $manifestCF

cat $manifestCF \
  | sed -e "s#.*instances.*#  instances: $instances §$pathapp#" \
  | sed -e "s#.* name:.*#- name: $cfpushappname#"  \
  | sed -e "s#.* VERSION:.*#    VERSION: $version#"  \
  | grep -v "route:" \
  | grep -v "routes:" \
  > $tfile1
cat $tfile1 | tr '§' '\n' > $manifestFinal
if [ "$printManifest" = true ] ; then
    cat $manifestFinal
else
    CF_TRACE=TRUE cf push -p $manifestFinal
    rc=$?; if [[ $rc != 0 ]]; then cat $manifestFinal; fi
fi
