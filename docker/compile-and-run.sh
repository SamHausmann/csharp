#!/bin/bash -e

ping_url="https://api.rosette.com/rest/v1"
retcode=0

#------------------ Functions ----------------------------------------------------

#Gets called when the user doesn't provide any args
function HELP {
    echo -e "\nusage: --API_KEY API_KEY [--FILENAME filename] [--ALT_URL altUrl]"
    echo "  API_KEY       - Rosette API key (required)"
    echo "  FILENAME      - C# source file"
    echo "  ALT_URL       - Alternate service URL (optional)"
    echo "  GIT_USERNAME  - Git username where you would like to push regenerated gh-pages (optional)"
    echo "  VERSION       - Build version (optional)"
    echo "Compiles and runs the source file using the local development source"
    exit 1
}

#Checks if Rosette API key is valid
function checkAPI {
    match=$(curl "${ping_url}/ping" -H "X-RosetteAPI-Key: ${API_KEY}" |  grep -o "forbidden")
    if [ ! -z $match ]; then
        echo -e "\nInvalid Rosette API Key"
        exit 1
    fi  
}

function cleanURL() {
    # strip the trailing slash off of the alt_url if necessary
    if [ ! -z "${ALT_URL}" ]; then
        case ${ALT_URL} in
            */) ALT_URL=${ALT_URL::-1}
                echo "Slash detected"
                ;;
        esac
        ping_url=${ALT_URL}
    fi
}

function validateURL() {
    match=$(curl "${ping_url}/ping" -H "X-RosetteAPI-Key: ${API_KEY}" |  grep -o "Rosette API")
    if [ "${match}" = "" ]; then
        echo -e "\n${ping_url} server not responding\n"
        exit 1
    fi  
}

function runExample() {
    result=""
    echo -e "\n---------- ${1} start -------------"
    executable=$(basename "${1}" .cs).exe
    mcs ${1} -r:rosette_api.dll -r:System.Net.Http.dll -r:System.Web.Extensions.dll -out:$executable
    result="$(mono $executable ${API_KEY} ${ALT_URL})"
    if [[ ${result} == *"Exception"* ]]; then
        retcode=1
    fi
    echo "${result}"
    echo "---------- ${1} end -------------"
}
#------------------ Functions End ------------------------------------------------

#Gets API_KEY, FILENAME and ALT_URL if present
while getopts ":API_KEY:FILENAME:ALT_URL:GIT_USERNAME:VERSION" arg; do
    case "${arg}" in
        API_KEY)
            API_KEY=${OPTARG}
            usage
            ;;
        ALT_URL)
            ALT_URL=${OPTARG}
            usage
            ;;
        FILENAME)
            FILENAME=${OPTARG}
            usage
            ;;
        GIT_USERNAME)
            GIT_USERNAME=${OPTARG}
            usage
            ;;
        VERSION)
            VERSION=${OPTARG}
            usage
            ;;
    esac
done

cleanURL

validateURL

#Copy the mounted content in /source to current WORKDIR
cp -r -n /source/. .

#Run the examples
if [ ! -z ${API_KEY} ]; then
    #Check API key and if succesful then build local rosette_api project
    checkAPI && nuget restore rosette_api.sln
    xbuild /p:Configuration=Release rosette_api.sln
    xbuild /p:Configuration=Debug rosette_api.sln
    #Copy necessary libraries
    cp /csharp-dev/rosette_api/bin/Release/rosette_api.dll /csharp-dev/rosette_apiExamples
    cp /csharp-dev/rosette_apiUnitTests/bin/Release/nunit.framework.dll /csharp-dev/rosette_apiUnitTests
    cp /csharp-dev/rosette_apiUnitTests/bin/Release/rosette_api.dll /csharp-dev/rosette_apiUnitTests
    #Change to dir where examples will be run from
    pushd rosette_apiExamples
    if [ ! -z ${FILENAME} ]; then
        runExample ${FILENAME}
    else
        for file in *.cs; do
            runExample ${file}
        done
    fi
    # Run the unit tests
    popd
    mono ./packages/NUnit.Console.3.0.1/tools/nunit3-console.exe ./rosette_apiUnitTests/bin/Debug/rosette_apiUnitTests.dll
else 
    HELP
fi

#Generate gh-pages and push them to git account (if git username and version are provided)
if [ ! -z ${GIT_USERNAME} ] && [ ! -z ${VERSION} ]; then
    #clone csharp git repo to the root dir
    cd /
    git clone git@github.com:${GIT_USERNAME}/csharp.git
    cd csharp
    git checkout origin/gh-pages -b gh-pages
    git branch -d develop
    #generate gh-pages from development source and output the contents to csharp repo
    cd /csharp-dev
    #configure doxygen
    doxygen -g rosette_api_dox
    sed -i '/^\bPROJECT_NAME\b/c\PROJECT_NAME = "rosette_api"' rosette_api_dox
    sed -i "/^\bPROJECT_NUMBER\b/c\PROJECT_NUMBER = $VERSION" rosette_api_dox
    sed -i '/^\bOPTIMIZE_OUTPUT_JAVA\b/c\OPTIMIZE_OUTPUT_JAVA = YES' rosette_api_dox
    sed -i '/^\bEXTRACT_ALL\b/c\EXTRACT_ALL = YES' rosette_api_dox
    sed -i '/^\bEXTRACT_STATIC\b/c\EXTRACT_STATIC = YES' rosette_api_dox
    sed -i '/^\bUML_LOOK\b/c\UML_LOOK = YES' rosette_api_dox
    sed -i '/^\bGENERATE_LATEX\b/c\GENERATE_LATEX = NO' rosette_api_dox
    sed -i '/^\bGENERATE_HTML\b/c\GENERATE_HTML = YES' rosette_api_dox
    sed -i '/^\bGENERATE_TREEVIEW\b/c\GENERATE_TREEVIEW = YES' rosette_api_dox
    sed -i '/^\bGRAPHICAL_HIERARCHY\b/c\GRAPHICAL_HIERARCHY = YES' rosette_api_dox
    sed -i '/^\bHAVE_DOT\b/c\HAVE_DOT = YES' rosette_api_dox
    sed -i '/^\bVERBATIM_HEADERS\b/c\VERBATIM_HEADERS = NO' rosette_api_dox
    sed -i '/^\bSOURCE_BROWSER\b/c\SOURCE_BROWSER = YES' rosette_api_dox
    sed -i '/^\bSHOW_FILES\b/c\SHOW_FILES = YES' rosette_api_dox
    sed -i '/^\bFULL_PATH_NAMES\b/c\FULL_PATH_NAMES = YES' rosette_api_dox
    sed -i '/^\bINPUT\b/c\INPUT = ./rosette_api' rosette_api_dox
    sed -i '/^\bFILE_PATTERNS\b/c\FILE_PATTERNS = *.c *.cc *.cxx *.cpp *.c++ *.java *.ii *.ixx *.ipp *.i++ *.inl *.h *.hh *.hxx *.hpp *.h++ *.idl *.odl *.cs *.php *.php3 *.inc *.m *.mm *.py *.f90' rosette_api_dox
    sed -i '/^\bOUTPUT_DIRECTORY\b/c\OUTPUT_DIRECTORY = /csharp' rosette_api_dox
    sed -i '/^\bHTML_OUTPUT\b/c\HTML_OUTPUT = HTML' rosette_api_dox
    #generate docs
    doxygen rosette_api_dox
    cd /csharp
    mv /csharp/HTML/* .
    rm -rd HTML
    git add .
    git commit -a -m "publish csharp apidocs ${VERSION}"
    git push
fi

exit ${retcode}

