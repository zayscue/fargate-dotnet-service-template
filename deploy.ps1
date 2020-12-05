#! /usr/bin/pwsh
param (
    [string]$account,
    [string]$region
)

function Confirm-Repository-Exists {
    param (
        $project
    )

    $repo = $project.Name.ToLower()
    $repoInfo = aws ecr describe-repositories --repository-names $repo 2>$null
    if (!$repoInfo) {
	    $repoInfo = aws ecr create-repository --repository-name $repo
	    $repoInfo = $repoInfo | ConvertFrom-Json
	    $repoInfo = $repoInfo.repository
    } else {
	    $repoInfo = $repoInfo | ConvertFrom-Json
	    $repoInfo = $repoInfo.repositories[0]
    }
    return $repoInfo
}

function Deploy {
    param (
        $awsAccount,
        $awsRegion,
        $projectName,
        $repoUri,
        $image,
        $tag = "latest",
        $templateFile
    )

    docker build -t $image -f "$($projectName)/Dockerfile" .
    docker tag "$($image):$($tag)" "$($repoUri):$($tag)"
    aws ecr get-login-password --region $awsRegion | docker login --username AWS --password-stdin "$($awsAccount).dkr.ecr.$($awsRegion).amazonaws.com"
    docker push "$($repoUri):$($tag)"
    aws cloudformation deploy --template-file $templateFile --stack-name todoapi --parameter-overrides RepoUri=$repoUri --capabilities CAPABILITY_NAMED_IAM
}

# Setting the default aws account and region
$defaultAWSAccount = ""
$defaultAWSRegion = ""

if (!$account) {
    $callerIdentity = aws sts get-caller-identity | ConvertFrom-Json
    $defaultAWSAccount = $callerIdentity.Account
} else {
    $defaultAWSAccount = $account
}

if (!$region) {
    $defaultAWSRegion = aws configure get region
} else {
    $defaultAWSRegion = $region
}

# Building the solution
Write-Output "Building Solution..."
dotnet build

# Testing the solution
Write-Output "Testing Solution..."
dotnet test

# Retrieving all the projects in the solution
$projects = Get-Content 'TodoService.sln' |
  Select-String 'Project\(' |
    ForEach-Object {
      $projectParts = $_ -Split '[,=]' | ForEach-Object { $_.Trim('[ "{}]') };
      New-Object PSObject -Property @{
        Name = $projectParts[1];
        File = $projectParts[2];
        Guid = $projectParts[3]
      }
    }

# Deploying each of the projects in the solution
foreach ($project in $projects) {
    if ($project.Name -ne 'Solution Items') {
        Write-Output "Ensuring that the container repository for the $($project.Name) project exists..."
        $repoInfo = Confirm-Repository-Exists -project $project
        Write-Output "Deploying $($project.Name)..."
        $templateFileRelativePath = ".\$($project.File.Substring(0, $project.File.LastIndexOf('\')))\template.yml"
        $fileInfo = Get-ItemProperty -Path $templateFileRelativePath
        $templateFileAbsolutePath = "$($fileInfo.DirectoryName)\$($fileInfo.Name)"
        Deploy -awsAccount $defaultAWSAccount -awsRegion $defaultAWSRegion -projectName $project.Name -repoUri $repoInfo.repositoryUri -image $project.Name.ToLower() -templateFile $templateFileAbsolutePath
    }
}
