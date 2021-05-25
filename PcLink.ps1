<#
Nextion <-> Powershell exemple
Copyright Cyrob under GNU General Public License v3.0

                 
 @@@@@@@@@@@@@@@  (@@@@@@   &@@@@       
 @@@@@@@@@@@@@@@  &@@@@@@  *@@@@@       
        .@@@@@@  #@@@@@@  .@@@@@@       
       #@@@@@@  &@@@@@@   @@@@@@@@@@@@@@
      #@@@@@@  @@@@@@@   @@@@@@@@@@@@@@@
     *@@@@@@  &@@@@@@            @@@@@@@
    .@@@@@@  @@@@@@@      @@@    @@@@@@@
    @@@@@@  @@@@@@@       @@@    @@@@@@@
    
    
Release history
24/05/2021  1.0  Phildem  First blood
25/05/2021  1.1  Phildem  Improve response time and Auto Max      

Data sent to Nextion every Second =======================================================

Time
Form: Main.Time.txt="<Current Time>"0xFF0xFF0xFF
Where <Current Time> is Current time in form HH:MM:SS
Exemple : Main.Time.txt="23:52:33"0xFF0xFF0xFF

Counter Max
Form: Main.Max.txt="<MaxValue>"0xFF0xFF0xFF
Where <MaxValue> is Max value in numeric form
Exemple : Main.Max.txt="500"0xFF0xFF0xFF

Counter
Form: Main.Cnt.txt="<CounterValue>"0xFF0xFF0xFF
Where <CounterValue> is Current counter value in numeric form
Exemple: Main.Cnt.txt="22"0xFF0xFF0xFF
 
Data received asynchronously from Nextion any time ======================================

Increment or decrement counter value
Form: Cnt<Inc>0x0D0x0A
Where <Inc> is the increment of the counter value in numeric form may be negativ or positiv
Exemple:  Cnt100x0D0x0A                                                    
Exemple:  Cnt-8x0D0x0A

Reset the counter
Form: Clr0x0D0x0A
Exemple:  Clrx0D0x0A

Stop PowerShell transmission
Form: Bye0x0D0x0A
Exemple:  Byex0D0x0A

#>


#------------------------------------------------------------------------------
# Send command to Nextion and add 3 FF
function WrNextion {

    param (
        $Value
    )

    $port.Write($Value)

    [Byte[]] $EOL = 0xFF,0xFF,0xFF
    $port.Write($EOL, 0, $EOL.Count)

    #uncomment following line to trace data sent to Nextion
    #Write-Host "Send $Value to Nextion"
}

#------------------------------------------------------------------------------

$Vers="1.1"
$Port="COM8"    #Change to the ComPort used to deal with Nextion

[int] $VMax=10        # Initial value Max of counter, any positv value
[int] $VCnt=0         # Initial counter value

Write-Host "PcLink version $Vers port $Port"

$port= new-Object System.IO.Ports.SerialPort $Port,9600,None,8,one
$port.open()

do{

    #Read Char from nextion if any
    if ($port.BytesToRead -ne 0){
        
        [Char]$Ch=$port.ReadChar()

        #Change CR to LF and Ignore nextion Error
        if ($Ch -eq [char]13){
            $Ch=[char]10
        } elseif ($Ch -eq [char]63){   #63 and not 255 due to Ps Char limitation
            $Ch=[char]10
            $NxData=""
        }

        if ($Ch -eq [char]10) {

            if ($NxData -ne "") {

                #Decode data from Nextion

                Write-Host "Received $NxData"

                if ($NxData.StartsWith("Cnt")){

                    $VCnt+=[Int]$NxData.Substring(3)

                    if ($VCnt -lt 0){     #Negativ value not allowed
                       $VCnt=0 
                    }

                    while ($VCnt -gt $VMax){    #Grow max if needed
                       $VMax*=10 
                    }


                } elseif ($NxData -eq "Clr"){
                    $VCnt=0
                    $VMax=10
                } elseif ($NxData.Contains("Bye")){
                    $port.Close()
                }

                $NxData=""
                $LastTime=""  #To improve response time
            }
        }
        else {
            [string]$NxData+=$Ch
        }
    }
    
    # Refresh data every Seconds
    $CurTime=Get-Date -Format HH:mm:ss
    if ($CurTime -ne $LastTime){

        $LastTime=$CurTime

        # Send Time
        $Cmd='Main.Time.txt="'
        $Cmd+=$CurTime
        $Cmd+='"'
        WrNextion $Cmd

        #Send Max
        $Cmd='Main.Max.txt="'
        $Cmd+=$VMax
        $Cmd+='"'
        WrNextion $Cmd

        #Send Cnt
        $Cmd='Main.Cnt.txt="'
        $Cmd+=$VCnt
        $Cmd+='"'
        WrNextion $Cmd
    }
    
} while ($port.IsOpen)

Write-Host "PcLink Complete"