Write-Host "2NIC-IP-Config"

# Get input from user
param(
    [string] [Parameter(Mandatory=$true)] $hostIPAddress,
    [string] [Parameter(Mandatory=$true)] $ethPrivateIPAddress,
    [string] [Parameter(Mandatory=$true)] $slbServerHost
  )

Write-Host "vThunder Host: " + $hostIPAddress
# # Connect to Azure portal
# Connect-AzAccount

# Base URL of AXAPIs
$BaseUrl = -join("https://", $hostIPAddress, "/axapi/v3")

function Get-AuthToken {
    param (
        $BaseUrl
    )
    # AXAPI Auth url 
    $Url = -join($BaseUrl, "/auth")
    # AXAPI header
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    # AXAPI Auth url json body
    $Body = "{
    `n    `"credentials`": {
    `n        `"username`": `"admin`",
    `n        `"password`": `"a10`"
    `n    }
    `n}"
    # Invoke Auth url
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $headers -Body $body
    # convert respnse to json
    $response | ConvertTo-Json
    # fetch Authorization token from response
    return $response
}

# Function to enable ethernet 1
function ConfigureEth1 {
    param (
        $BaseUrl,
        $AuthorizationToken
    )
    # AXAPI ethernet 1 Url
    $Url = -join($BaseUrl, "/interface/ethernet/1")
    
    # AXAPI interface url headers
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

    $Body = "{
        `n  `"ethernet`": {
        `n    `"ifnum`": 1,
        `n    `"action`": `"enable`",
        `n    `"ip`": {
        `n      `"dhcp`": 0,
        `n      `"address-list`": [
        `n        {
        `n          `"ipv4-address`": `"10.0.2.5`",
        `n          `"ipv4-netmask`": `"255.255.255.224`"
        `n        }
        `n      ]
        `n    }
        `n  }
        `n}"

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
    $response | ConvertTo-Json
    Write-Host "Enabled ethernet 1"
}

# Create server s1
function ConfigureServerS1 {
    param (
        $BaseUrl,
        $AuthorizationToken
    )
    # AXAPI ethernet 1 Url
    $Url = -join($BaseUrl, "/slb/server")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")
    
    $Body = "{
        `n  `"server`": {
        `n    `"name`": `"s1`",
        `n    `"host`": `"10.0.2.6`",
        `n    `"port-list`": [
        `n        {
        `n          `"port-number`":53,
        `n          `"protocol`":`"udp`" 
        `n        },
        `n        {
        `n          `"port-number`":80,
        `n          `"protocol`":`"tcp`"
        `n        },
        `n        {
        `n          `"port-number`":443,
        `n          `"protocol`":`"tcp`"
        `n        }
        `n      ]
        `n  }
        `n}"

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
    $response | ConvertTo-Json
    Write-Host "Configured server s1"
}

function ConfigureServiceGroup {
    param (
        $BaseUrl,
        $AuthorizationToken
    )
    $Url = -join($BaseUrl, "/slb/service-group")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

    $Body = "{
        `n  `"service-group-list`": [
        `n    {
        `n      `"name`":`"sg443`",
        `n      `"protocol`":`"tcp`",
        `n      `"member-list`": [
        `n        {
        `n          `"name`":`"s1`",
        `n          `"port`":443
        `n        }
        `n      ]
        `n    },
        `n    {
        `n      `"name`":`"sg53`",
        `n      `"protocol`":`"udp`"
        `n      `"member-list`": [
        `n        {
        `n          `"name`":`"s1`",
        `n          `"port`":53
        `n        }
        `n      ]
        `n    },
        `n     {
        `n      `"name`":`"sg80`",
        `n      `"protocol`":`"tcp`"
        `n      `"member-list`": [
        `n        {
        `n          `"name`":`"s1`",
        `n          `"port`":80
        `n        }
        `n      ]
        `n    }
        `n  ]
        `n}
        `n
        `n"
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
    $response | ConvertTo-Json
    Write-Host "Configured service group"
}

function ConfigureVirtualServer {
    param (
        $BaseUrl,
        $AuthorizationToken
    )
    $Url = -join($BaseUrl, "/slb/virtual-server")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")
    
    $Body = "{
        `n  `"virtual-server-list`": [
        `n    {
        `n      `"name`":`"vsl`",
        `n      `"use-if-ip`":1,
        `n      `"ethernet`":1,
        `n      `"port-list`": [
        `n        {
        `n          `"port-number`":53,
        `n          `"protocol`":`"udp`",
        `n          `"auto`":1,
        `n          `"service-group`":`"sg53`"
        `n        },
        `n        {
        `n          `"port-number`":80,
        `n          `"protocol`":`"http`",
        `n          `"auto`":1,
        `n          `"service-group`":`"sg80`"
        `n        },
        `n        {
        `n          `"port-number`":443,
        `n          `"protocol`":`"https`",
        `n          `"auto`":1,
        `n          `"service-group`":`"sg443`"
        `n        }
        `n      ]
        `n    }
        `n  ]
        `n}
        `n"
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
    $response | ConvertTo-Json
    Write-Host "Configured service group"
}

# Call above functions
# Invoke Get-AuthToken
$Response = Get-AuthToken -BaseUrl $BaseUrl
$AuthorizationToken = $Response.authresponse.signature
# Invoke Enable-Eth1
ConfigureEth1 -BaseUrl $BaseUrl -AuthorizationToken $AuthorizationToken
# Invoke CreateServerS1
ConfigureServerS1 -BaseUrl $BaseUrl -AuthorizationToken $AuthorizationToken
# Invoke ConfigureServiceGroup
ConfigureServiceGroup -BaseUrl $BaseUrl -AuthorizationToken $AuthorizationToken
# Invoke ConfigureVirtualServer
ConfigureVirtualServer -BaseUrl $BaseUrl -AuthorizationToken $AuthorizationToken