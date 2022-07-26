Param(
   $source = [PSCustomObject]@{
          organization=""
          project= ""
          pat= ""},
   $destination =  [PSCustomObject]@{
          organization=""
          project= ""
          pat= ""},
   $user = "",
   $tempFilePath = ".\pipelines\",
   $filePath = ".\pipelines-converted\"
           
)

#function
# Base64-encodes the Personal Access Token (PAT) appropriately
function authOf ($tkn) {
  $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$tkn)))
  $header = @{Authorization=("Basic {0}" -f $base64AuthInfo)}
  return $header
  
}

#getproject,organisation
function GetProjectName ($x) {
  $prj=$x.project
  return $prj
  }
function GetProjectOrg ($x) {
  $org=$x.organization
  return $org 
}
function getpipelinesByID ($url,$tkn) {
  Write-Host "url by id : $url"
  $header= authOf $tkn
  $x = Invoke-RestMethod -Uri $url -Method 'Get' -Headers $header
  $list = [System.Collections.ArrayList]::new()
  # $list = @()
  foreach ($d in $x) {
    <# $d is the current item #>
    $config=$d.configuration
    $name=$d.name
    $fold=$d.folder
    $list.Add(@{"configuration"=$config;"name"=$name;"folder"=$fold})
  }
    $list | ConvertTo-Json -Depth 10 | Out-File ".\pipelines\$name.json"
}

function GetSourcePipelines ($src,$dst) {
  $org=$src.organization
  $proj=$src.project
  $tkn=$src.pat
  $url = "https://dev.azure.com/$org/$proj/_apis/pipelines?api-version=6.1-preview.1"
  Write-Host "Url source : $url"
  $header= authOf $tkn
  $data = Invoke-RestMethod -Uri $url -Method 'Get' -Headers $header
  foreach ($pip in $data) {
    <# $pipelines is the current item #>
    foreach ($val in $data.value) {
      <# $valx is the current item #>
      $idx=@($val.id)
      $idx | ForEach-Object  {
        $url="https://dev.azure.com/$org/$proj/_apis/pipelines/"+"$_"+"?api-version=6.1-preview.1"
        getpipelinesByID $url $tkn
      }
    }
  }
}
function PutOnTargetPipelines ($dst) { 
  $org=$dst.organization
  $proj=$dst.project
  $tkn=$dst.pat
  $url="https://dev.azure.com/$org/$proj/_apis/pipelines?api-version=6.1-preview.1"
  Write-Host "Url dst : $url"
  $localfolder = ".\pipelines-converted\"
  $localfiles = Get-ChildItem $localfolder 
  ForEach ($LocalFile in $localfiles) 
  {     
    # write-host "file $localfolder$LocalFile"
    $json = Get-Content $localfolder$LocalFile
    $header= authOf $tkn
    Invoke-RestMethod -Uri $url -Method 'Post' -ContentType "application/json" -Body $json -Headers $header
    Start-Sleep -Seconds 1.5
  }
}
function RemplaceIdOnJson ($data) {
  # $liste=New-Object System.Collections.Generic.List[System.Object]
  foreach ($n in $data) {
    <# $n is the current item #>
    $nom=$n.name
    $path=".\pipelines\"+$nom+".json"
    if (Test-Path $path -PathType leaf) 
    {
    $file=Get-Content $path | ConvertFrom-Json
    $file.configuration.repository.id=$n.id 
    write-host "file $file"
    $pathdest=".\pipelines-converted\"+$nom+".json"
    $file |ConvertTo-Json -Depth 10 | Set-Content $pathdest
    # $liste += "$file" |ConvertTo-Json -Depth 10
    }  
  else
  {"File does not exist"} 
  } 
}
function UpdateRepositoryId ($dst) {
  $org=$dst.organization
  $proj=$dst.project
  $tkn=$dst.pat
  $url="https://dev.azure.com/$org/$proj/_apis/git/repositories?api-version=6.1-preview.1"
  Write-Host "Url dst : $url"
  $header= authOf $tkn
  $data = Invoke-RestMethod -Uri $url -Method 'Get' -Headers $header
  $list = [System.Collections.ArrayList]::new()
  foreach ($d in $data.value) {
    <# $d is the current item #>
    $idx=$d.id
    $namex=$d.name
    
    $list.Add([PSCustomObject]@{
      id=$idx
      name=$namex})
  }
  RemplaceIdOnJson $list
}
function MigratePipelines ($src, $dst) {
  GetSourcePipelines $src $dst
  UpdateRepositoryId $dst
  PutOnTargetPipelines $dst
}
if (-not ([string]::IsNullOrEmpty($source))) {
  MigratePipelines $source $destination
  return $source
} 
else {
  Write-Output "sources Name does not exist"
}

