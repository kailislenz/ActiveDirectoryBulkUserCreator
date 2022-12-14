#region GlobalFunctions

############################################################################################################
#region MainForm functions
$MainForm_Load = {
    $calendarExpirationDate.MinDate = (Get-Date).AddDays(1)

    $defaultHeaders = ('SamAccountName', 'Account Password')
    $availableItems = $userDictionary.PSObject.Properties | Where-Object {($defaultHeaders -notcontains $_.Name)}
    $selectedItems = $userDictionary.PSObject.Properties | Where-Object {($defaultHeaders -contains $_.Name)}

    PopulateColumnLists -AvailableItems $availableItems -SelectedItems $selectedItems
    PopulateDataGridColumns -Headers $listEditColumnsSelected.Items.Name
    $datagridMainUser.Rows.Add()

    $bEditColumnsUp.Text = [char]0x25B2
    $bEditColumnsDown.Text = [char]0x25BC
    $bEditColumnsRemove.Text = [char]0x2190
    $bEditColumnsAdd.Text = [char]0x2192
}
$datagridMainUser_DefaultValuesNeeded = {
}
$datagridMainUser_CellValueChanged = {

    $bMainNext.Enabled = $false    
    $Global:callerCell = $datagridMainUser.Rows[$_.RowIndex].Cells[$_.ColumnIndex]
    $currentColumns = $datagridMainUser.Columns.Name
    $inverseColumn = $inverseData.($callerCell.OwningColumn.Name)

    HandleCellError -Cell $callerCell

    if($currentColumns -contains $inverseColumn){
        $targetCell = $datagridMainUser.Rows[$callerCell.RowIndex].Cells[$inverseColumn]
        if($callerCell.Value -eq $true){
            ToggleCell -Cell $targetCell -Enable $false
        }
        else{
            ToggleCell -Cell $targetCell -Enable $true
        }
    }

    if($userDictionary.($callerCell.OwningColumn.Name).Type -eq 'Boolean'){
        $callerCell.Tag = $callerCell.FormattedValue
    }
    
}
$datagridMainUser_CellContentClick = {
    $Global:callerCell = $datagridMainUser.Rows[$_.RowIndex].Cells[$_.ColumnIndex]

    if($callerCell.OwningColumn.Name -eq 'Account Expiration Date'){
        $FormExpirationDate.ShowDialog()
    }
    elseif($callerCell.OwningColumn.Name -eq 'Logon Workstations'){
        $FormLogonWorkstations.ShowDialog()
    }
    <#elseif($callerCell.OwningColumn.Name -eq 'Organizational Unit'){
        Write-Host 'organizational'
    }#>
    elseif($callerCell.OwningColumn.Name -eq 'Security Groups'){
        $FormSecurityGroups.ShowDialog()
    }

    if($userDictionary.($callerCell.OwningColumn.Name).Type -eq 'Boolean'){
        $datagridMainUser.EndEdit()
    }
}

$bMainEditColumns_Click = {
    $FormEditColumns.ShowDialog()
}
$bMainAddRows_Click = {
    $FormAddRows.ShowDialog()
}
$bMainLoadPreset_Click = {
    $dialogResult = $openFileDialog.ShowDialog()

    if($dialogResult -eq "OK"){
        $loadPreset = Import-Csv $openFileDialog.FileName
        $headers = $loadPreset[0].PSObject.Properties.Name
        $headerValidation = ValidateHeaders -Headers $headers
        if($headerValidation -eq $null){
            $datagridMainUser.Rows.Clear()
            $datagridMainUser.Rows.Add()
            CorrectSelectedList -Headers $headers
            PopulateDataGridColumns -Headers $headers
        }
        else{
            $badHeaders = "Invalid Headers:" + "`r`n" + ($headerValidation -join "`r`n")
            [System.Windows.MessageBox]::Show($badHeaders, 'Invalid Headers', 'OK')
        }
    }
}
$bMainSavePreset_Click = {
    $savePreset = [PSCustomObject]@{}

    foreach($header in $datagridMainUser.Columns.Name){
        $savePreset | Add-Member -NotePropertyName $header -NotePropertyValue $null
    }
    $dialogResult = $saveFileDialog.ShowDialog()

    if($dialogResult -eq "OK"){
        $savePreset | Export-Csv $saveFileDialog.FileName -NoTypeInformation
    }
}
$bMainImportCSV_Click = {
    $dialogResult = $openFileDialog.ShowDialog()

    if($dialogResult -eq "OK"){
        $loadPreset = Import-Csv $openFileDialog.FileName
        $headers = $loadPreset[0].PSObject.Properties.Name

        if($headerValidation -eq $null){
            $datagridMainUser.Rows.Clear()
            CorrectSelectedList -Headers $headers
            PopulateDataGridColumns -Headers $headers
            for($i = 0; $i -lt @($loadPreset).Count; $i++){
                $datagridMainUser.Rows.Add()
                foreach($header in $headers){
                    if($userDictionary.$header.Type -eq 'Textbox'){
                        $datagridMainUser.Rows[$i].Cells[$header].Value = $loadPreset[$i].$header
                    }
                }
            }
        }
        else{
            $badHeaders = "Invalid Headers:" + "`r`n" + ($headerValidation -join "`r`n")
            [System.Windows.MessageBox]::Show($badHeaders, 'Invalid Headers', 'OK')
        }
    }
}
$bMainClearSheet_Click = {
    $result = [System.Windows.MessageBox]::Show('Clear all cells on sheet?', 'Clear Data', 'YesNo')
    if($result -eq 'Yes'){
        $datagridMainUser.Rows.Clear()
        $datagridMainUser.Rows.Add()
    }
}
$bMainValidate_Click = {
    $datagridMainUser.EndEdit()

    $errorCount = 0
    foreach($row in $datagridMainUser.Rows){
        foreach($cell in $row.Cells){
            HandleCellError -Cell $cell
            if($cell.ErrorText.Length -gt 0){
                $errorCount++
            }
        }
    }
    if($errorCount -gt 0){
        $message = "Datagrid contains " + $errorCount.ToString() + " errors!"
        [System.Windows.MessageBox]::Show($message, 'Datagrid validation failed', 'OK')
    }
    else{
        $bMainNext.Enabled = $true
    }
}
$bMainNext_Click = {
    $Error.Clear()
    $userTable = CreateDataTable
    foreach($user in $userTable){
        $Error.Clear()
        CreateADUser -lineAttributes $user
        if($Error){
            $errorHeader = "Process Error"
            $errorBody = "Error while creating " + $user.SamAccountName +":`r`n`r`n" +  $Error[0].Exception.Message + "`r`n`r`nWould you like to continue processing users?"
            $result = [System.Windows.MessageBox]::Show($errorBody, $errorHeader, 'YesNo')
            if($result -eq 'No'){
                break
            }
        }
    }
    [System.Windows.MessageBox]::Show('All users have been processed!', 'Process Complete', 'OK')
    $bMainNext.Enabled = $false
}
#endregion MainForm functions


############################################################################################################
#region AddRows functions
$FormAddRows_Load = {
    $nudAddRows.Value = 1
}
$nudAddRows_ValueChanged = {
}
$bAddRowsCancel_Click = {
}
$bAddRowsOK_Click = {
    for($i = 1; $i -le $nudAddRows.Value; $i++){
        $datagridMainUser.Rows.Add()
    }
    $FormAddRows.Close()
}
#endregion AddRows functions


############################################################################################################
#region EditColumns functions
$FormEditColumns_Load = {
    $Global:listAvailableSnapshot = $listEditColumnsAvailable.Items | select *
    $Global:listSelectedSnapshot = $listEditColumnsSelected.Items | select *
}
$listEditColumnsSelected_SelectedIndexChanged = {
}
$listEditColumnsAvailable_SelectedIndexChanged = {
}
$bEditColumnsAdd_Click = {
    $swapItems = $listEditColumnsAvailable.SelectedItems
    SwapListData -Items $swapItems -SourceList $listEditColumnsAvailable -TargetList $listEditColumnsSelected
}
$bEditColumnsRemove_Click = {
    $swapItems = $listEditColumnsSelected.SelectedItems
    SwapListData -Items $swapItems -SourceList $listEditColumnsSelected -TargetList $listEditColumnsAvailable
}
$bEditColumnsUp_Click = {
    $selectedItems = $listEditColumnsSelected.SelectedItems
    if($selectedItems[0].Index -ne 0){
        foreach($item in $selectedItems){
            $itemIndex = $item.Index
            $listEditColumnsSelected.Items.Remove($item)
            $listEditColumnsSelected.Items.Insert(($itemIndex - 1), $item)
        }
    }
}
$bEditColumnsDown_Click = {
    $selectedItems = $listEditColumnsSelected.SelectedItems | Sort-Object Index -Descending
    $itemIndexCount = $listEditColumnsSelected.Items.Count - 1
    if($selectedItems[0].Index -ne $itemIndexCount){
        foreach($item in $selectedItems){
            $itemIndex = $item.Index
            $listEditColumnsSelected.Items.Remove($item)
            $listEditColumnsSelected.Items.Insert(($itemIndex + 1), $item)
        }
    }
}
$bEditColumnsCancel_Click = {
    CorrectSelectedList -Headers $listSelectedSnapshot.Name
}
$bEditColumnsOK_Click = {
    PopulateDataGridColumns -Headers $listEditColumnsSelected.Items.Name
    $FormEditColumns.Close()
}
#endregion EditColumns functions


############################################################################################################
#region LogonWorkstations functions
$FormLogonWorkstations_Load = {
    if(($callerCell.Value -eq $null) -or ($callerCell.Tag -ne $null)){
        $tbLogonWorkstations.Text = $callerCell.Tag -replace "`,","`r`n"
        $cbLogonWorkstations.Checked = $false
        $tbLogonWorkstations.Enabled = $true
        $bLogonWorkstationsVerify.Enabled = $true
        $bLogonWorkstationsOK.Enabled = $false 
    }
    else{
        $cbLogonWorkstations.Checked = $true
        $tbLogonWorkstations.Text = $null
        $tbLogonWorkstations.Enabled = $false
        $bLogonWorkstationsVerify.Enabled = $false
        $bLogonWorkstationsOK.Enabled = $true 
    }
}
$tbLogonWorkstations_TextChanged = {
    $bLogonWorkstationsOK.Enabled = $false
}
$bLogonWorkstationsVerify_Click = {
    $userInput = $tbLogonWorkstations.Text -split "`r`n"
    $userInput = ($userInput | Where-Object {$_ -ne ""})

    $goodWorkstations = @()
    $badWorkstations = @()
    foreach($workstation in $userInput){
        $workstation = $workstation.TrimEnd()
        try{
           $goodWorkstations += (Get-ADComputer $workstation).Name
        }
        catch{
            $badWorkstations += $workstation
        }
    }
    if($badWorkstations.Count -eq 0){
        [System.Windows.MessageBox]::Show('All workstations verified!', 'Logon Workstations', 'OK')
        $tbLogonWorkstations.Text = ($goodWorkstations -join "`r`n")
        $blogonWorkstationsOK.Enabled = $true
    }
    else{
        $badWorkstations = "Could not find the following workstations:" + "`r`n" + ($badWorkstations -join "`r`n")
        [System.Windows.MessageBox]::Show($badWorkstations, 'Logon Workstations', 'OK')
        $blogonWorkstationsOK.Enabled = $false
    }
}
$cbLogonWorkstations_CheckedChanged = {
    if($cbLogonWorkstations.Checked -eq $true){
        $tbLogonWorkstations.Text = $null
        $tbLogonWorkstations.Enabled = $false
        $bLogonWorkstationsVerify.Enabled = $false
        $bLogonWorkstationsOK.Enabled = $true
    }
    else{
        $tbLogonWorkstations.Enabled = $true
        $bLogonWorkstationsVerify.Enabled = $true
        $bLogonWorkstationsOK.Enabled = $false
    }
}
$bLogonWorkstationsCancel_Click = {
}
$bLogonWorkstationsOK_Click = {
    if($cbLogonWorkstations.Checked -eq $true){
        $callerCell.Tag = $null
        $callerCell.Value = "All Computers"
    }
    else{
        $logonWorkstations = $tbLogonWorkstations.Text -split "`r`n"
        $callerCell.Tag = $logonWorkstations -join ","
        $callerCell.Value = $logonWorkstations.Count.ToString() + " Selected"
    }
    $FormLogonWorkstations.Close()
}
#endregion LogonWorkstations functions


############################################################################################################
#region SecurityGroups functions
$FormSecurityGroups_Load = {
    if(($callerCell.Value -eq $null) -or ($callerCell.Tag -ne $null)){
        $cbSecurityGroups.Checked = $false
        $tbSecurityGroups.Text = $callerCell.Tag -replace "`,","`r`n"
        $tbSecurityGroups.Enabled = $true
        $bSecurityGroupsVerify.Enabled = $true
        $bSecurityGroupsOK.Enabled = $false 
    }
    else{
        $cbSecurityGroups.Checked = $true
        $tbSecurityGroups.Text = $null
        $tbSecurityGroups.Enabled = $false
        $bSecurityGroupsVerify.Enabled = $false
        $bSecurityGroupsOK.Enabled = $true
    }   
}
$tbSecurityGroups_TextChanged = {
    $bSecurityGroupsOK.Enabled = $false
}
$bSecurityGroupsVerify_Click = {
    $userInput = $tbSecurityGroups.Text -split "`r`n"
    $userInput = ($userInput | Where-Object {$_ -ne ""})

    $goodGroups = @()
    $badGroups = @()
    foreach($group in $userInput){
        $group = $group.TrimEnd()
        try{
           $goodGroups += (Get-ADGroup $group).Name
        }
        catch{
            $badGroups += $group
        }
    }
    if($badGroups.Count -eq 0){
        [System.Windows.MessageBox]::Show('All groups verified!', 'Security Groups', 'OK')
        $tbSecurityGroups.Text = ($goodGroups -join "`r`n")
        $bSecurityGroupsOK.Enabled = $true
    }
    else{
        $badGroups = "Could not find the following security groups:" + "`r`n" + ($badGroups -join "`r`n")
        [System.Windows.MessageBox]::Show($badGroups, 'Security Groups', 'OK')
        $bSecurityGroupsOK.Enabled = $false
    }
}
$cbSecurityGroups_CheckedChanged = {
    if($cbSecurityGroups.Checked -eq $true){
        $tbSecurityGroups.Text = $null
        $tbSecurityGroups.Enabled = $false
        $bSecurityGroupsVerify.Enabled = $false
        $bSecurityGroupsOK.Enabled = $true
    }
    else{
        $tbSecurityGroups.Enabled = $true
        $bSecurityGroupsVerify.Enabled = $true
        $bSecurityGroupsOK.Enabled = $false
    }
}
$bSecurityGroupsCancel_Click = {
}
$bSecurityGroupsOK_Click = {
    if($cbSecurityGroups.Checked -eq $true){
        $callerCell.Tag = $null
        $callerCell.Value = "No Groups Selected"
    }
    else{
        $securityGroups = $tbSecurityGroups.Text -split "`r`n"
        $callerCell.Tag = $securityGroups -join ","
        $callerCell.Value = $securityGroups.Count.ToString() + " Selected"
    }
    $FormSecurityGroups.Close()
}
#endregion SecurityGroups functions


############################################################################################################
#region MonthCalendar functions
$FormExpirationDate_Load = {
    if($callerCell.Value -eq $null){
        $calendarExpirationDate.SelectionStart = $calendarExpirationDate.MinDate
        $calendarExpirationDate.Enabled = $true
        $cbExpirationDate.Checked = $false
    }
    elseif($callerCell.Tag -ne $null){
        $calendarExpirationDate.Enabled = $true
        $cbExpirationDate.Checked = $false
        $calendarExpirationDate.SelectionStart = $callerCell.Tag
    }
    else{
        $calendarExpirationDate.SelectionStart = $calendarExpirationDate.MinDate
        $calendarExpirationDate.Enabled = $false
        $cbExpirationDate.Checked = $true
    }
}
$calendarExpirationDate_DateChanged = {
}
$cbExpirationDate_CheckedChanged = {
    if($cbExpirationDate.Checked -eq $true){
        $calendarExpirationDate.Enabled = $false
    }
    else{
        $calendarExpirationDate.Enabled = $true
    }
}
$bExpirationDateCancel_Click = {
}
$bExpirationDateOK_Click = {
    if($cbExpirationDate.Checked -eq $true){
        $callerCell.Value = 'No Expiration Date'
        $callerCell.Tag = $null
    }
    else{
        $callerCell.Value = $calendarExpirationDate.SelectionStart.ToShortDateString()
        $callerCell.Tag = $calendarExpirationDate.SelectionStart
    }
    $FormExpirationDate.Close()
}
#endregion MonthCalendar functions


############################################################################################################
#region Misc functions

function PopulateDataGridColumns($Headers){
    $i = 0
    foreach($header in $Headers){
        $columnDefaults = $userDictionary.$header

        if($datagridMainUser.Columns.Name -notcontains $header){
            if($columnDefaults.Type -eq 'Boolean'){
                $dataColumn =  New-Object -TypeName System.Windows.Forms.DataGridViewCheckBoxColumn
                $dataColumn.CellTemplate.Tag = $columnDefaults.DefaultValue
            }
            elseif($columnDefaults.Type -eq 'Button'){
                $dataColumn = New-Object -TypeName System.Windows.Forms.DataGridViewButtonColumn
                #$dataColumn.CellTemplate.Tag = $columnDefaults.DefaultValue
            }
            else{
                $dataColumn =  New-Object -TypeName System.Windows.Forms.DataGridViewTextBoxColumn
                $dataColumn.MaxInputLength = $columnDefaults.RangeUpper
            }

            $dataColumn.HeaderText = $columnDefaults.Friendly
            $dataColumn.Name = $columnDefaults.Friendly
            $dataColumn.DefaultCellStyle.NullValue = $columnDefaults.DefaultValue
            $dataColumn.MinimumWidth = 125
            $datagridMainUser.Columns.Add($dataColumn)

        }
        $datagridMainUser.Columns[$columnDefaults.Friendly].DisplayIndex = $i
        $i++
    }
    foreach($column in $datagridMainUser.Columns.Name){
        if($Headers -notcontains $column){
            if(($inverseData.$column) -and ($datagridMainUser.Columns[$inverseData.$column])){
                for($i = 0; $i -lt $datagridMainUser.Rows.Count; $i++){
                    $toggleCell = $datagridMainUser.Rows[$i].Cells[$inverseData.$column]
                    ToggleCell -Cell $toggleCell -Enable $true
                }
            }
            $datagridMainUser.Columns.Remove($column)
        }
    }
}

function PopulateColumnLists($AvailableItems, $SelectedItems){
    foreach($item in $AvailableItems){
        $listViewItem = New-Object System.Windows.Forms.ListViewItem
        $listViewItem.Name = $item.Name
        $listViewItem.Text = $item.Name
        $listViewItem.Group = $item.Value.Category
        $listViewItem.Tag = $item.Value.Category
        $listEditColumnsAvailable.Items.Add($listViewItem)
        $listEditColumnsAvailable.Groups[$item.Value.Category].Items.Add($listViewItem)
    }
    foreach($item in $SelectedItems){
        $listViewItem = New-Object System.Windows.Forms.ListViewItem
        $listViewItem.Name = $item.Name
        $listViewItem.Text = $item.Name
        $listViewItem.Group = $item.Value.Category
        $listViewItem.Tag = $item.Value.Category
        $listEditColumnsSelected.Items.Add($listViewItem)
        $listEditColumnsSelected.Groups[$item.Value.Category].Items.Add($listViewItem)
    }
}

function SwapListData($Items, $SourceList, $TargetList){
    foreach($item in $Items){
        if(($item.Text -ne 'SamAccountName') -and ($item.Text -ne 'Account Password')){
            $SourceList.Items.Remove($item)
            $TargetList.Items.Add($item)
            $TargetList.Groups[$item.Tag].Items.Add($item)
        }
    }
}

function ToggleCell($Cell, [boolean]$Enable){
    if($Enable -eq $false){
        $Cell.ReadOnly = $true
        $Cell.Style.BackColor = 'DarkGray'
        $Cell.Style.SelectionBackColor = 'DarkGray'
        $Cell.Value = $null 
        $Cell.ErrorText = $null     
    }
    else{
        $Cell.ReadOnly = $false
        $Cell.Style.BackColor = 'White'
        $Cell.Style.SelectionBackColor = 'Highlight'
    }
}

function CorrectSelectedList($Headers){
    $toAvailableItems = $listEditColumnsSelected.Items | Where-Object {$Headers -notcontains $_.Name}
    $toSelectedItems = $listEditColumnsAvailable.Items | Where-Object {$Headers -contains $_.Name}
    SwapListData -Items $toAvailableItems -SourceList $listEditColumnsSelected -TargetList $listEditColumnsAvailable
    SwapListData -Items $toSelectedItems -SourceList $listEditColumnsAvailable -TargetList $listEditColumnsSelected
}

function CreateDataTable(){
    $dataArray = @()
    for($i = 0; $i -lt $datagridMainUser.RowCount; $i++){
        $rowObject = [PSCustomObject]@{}
        foreach($column in $datagridMainUser.Columns.Name){
            $cellDetails = $datagridMainUser.Rows[$i].Cells[$column]
            if(($userDictionary.$column).Type -eq 'Button'){
                $cellValue = $cellDetails.Tag
            }
            elseif(($userDictionary.$column).Type -eq 'Boolean'){
                $cellValue = $cellDetails.FormattedValue
            }
            elseif(($userDictionary.$column).Type -eq 'Textbox'){
                $cellValue = $cellDetails.Value
            }
            $rowObject | Add-Member -NotePropertyName ($userDictionary.$column).Actual -NotePropertyValue $cellValue
        }
        $dataArray += $rowObject
    }
    return $dataArray
}

function CreateADUser($lineAttributes){
    $args = @{}

    $attributesToParse = ($lineAttributes.PSObject.Properties | Where-Object {($_.Value -ne $null) -and ($_.Name -ne 'MemberOf')}).Name

    foreach($attribute in $attributesToParse){
        $attributeValue = $lineAttributes.$attribute
        if($attribute -eq 'AccountPassword'){
            $attributeValue = ($attributeValue | ConvertTo-SecureString -AsPlainText -Force)
        }
        $args.$attribute = $attributeValue
    }

    if($lineAttributes.'Enabled' -eq $null){
        $args.'Enabled' = $true
    }
    if(!($lineAttributes.'Name')){
        $nameCheck = @($lineAttributes.'GivenName', $lineAttributes.'Initials', $lineAttributes.'Surname')
        $nameCheck = ($nameCheck | Where-Object {$_ -ne $null})
        if($nameCheck.Count -gt 0){
            $args.'Name' = $nameCheck -join " "
        }
        else{
            $args.'Name' = $lineAttributes.'SamAccountName'
        }
    }

    New-ADUser @args -ErrorVariable $badOutput

    if($badOutput -ne $null){
        return $badOutput
    }
    
    if($lineAttributes.'MemberOf'){
        $securityGroups = $lineAttributes.'MemberOf' -split ","
        foreach($group in $securityGroups){
            Add-ADGroupMember -Identity $group -Members ($lineAttributes.'SamAccountName')
        }
    }

}

function HandleCellError($Cell){

    $cellRow = $Cell.OwningRow.Index
    $cellColumn = $Cell.OwningColumn.Name
    $cellLength = $Cell.Value.Length
    $cellDictionary = $userDictionary.$cellColumn

    if(($cellDictionary.RangeUpper -ne $null) -and ($cellLength -gt $cellDictionary.RangeUpper)){
        $Cell.ErrorText = $cellColumn + " cannot exceed " + $cellDictionary.RangeUpper + " characters!"
    }
    else{
        $Cell.ErrorText = $null
    }

    if($cellColumn -eq 'SamAccountName'){
        try{
            Get-ADUser $Cell.Value
            $Cell.ErrorText = $Cell.Value + " already exists!"
        }
        catch{
            $Cell.ErrorText = $null
        }
        if($Cell.Value.Length -lt 1){
            $Cell.ErrorText = 'Required Value!'    
        }
    }

    elseif($cellColumn -eq 'Manager'){
        if(($Cell.Value -ne "") -and ($Cell.Value -ne $null)){
            try{
                Get-ADUser $Cell.Value
                $Cell.ErrorText = $null
            }
            catch{
                $Cell.ErrorText = "Cannot find user!"
            }
        }
        else{
            $Cell.ErrorText = $null
        }
    }

    elseif(($cellColumn -eq 'Account Password') -and ($Cell.ReadOnly -eq $false)){
        $complexityCount = 0
        $complexityStrings = @('[A-Z]', '[a-z]', '[0-9]')
        $passwordPolicy = Get-ADDefaultDomainPasswordPolicy
 
        if($cellLength -lt $passwordPolicy.MinPasswordLength){
            $Cell.ErrorText = "Password must at least " + $passwordPolicy.MinPasswordLength.ToString() + " characters!"
        }

        elseif($passwordPolicy.ComplexityEnabled -eq $true){
            foreach($string in $complexityStrings){
                if($Cell.Value -cmatch $string){
                    $complexityCount++
                }
            }
            if($Cell.Value -notmatch '^[a-zA-Z0-9]+$'){
                $complexityCount ++
            }
            if($complexityCount -lt 3){
                $Cell.ErrorText = "Password may not meet the complexity requirement of the domain."
            }
        }
        elseif(($row.Cells['Password Not Required'].Value -ne $true) -and ($cell.Value.Length -eq 0)){
            $cell.ErrorText = 'Required Value!'
        }
    }
    else{
        $cell.ErrorText = $null
    }
}

function ValidateHeaders($Headers){
    $badHeaders = @()

    foreach($header in $Headers){
        if(!($userDictionary.$header)){
            $badHeaders += $header
        }
    }

    if($badHeaders.Count -gt 0){
        return $badHeaders
    }
}
#endregion Misc functions


############################################################################################################
#region Dictionaries
$Global:userDictionary = [PSCustomObject]@{
     'SamAccountName' = [PSCustomObject]@{
            Actual = 'SamAccountName'
            Friendly = 'SamAccountName'
            Category = 'General'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 20
     }
     'Account Password' = [PSCustomObject]@{
            Actual = 'AccountPassword'
            Friendly = 'Account Password'
            Category = 'General'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 128
     }
     'Account Expiration Date' = [PSCustomObject]@{
            Actual = 'AccountExpirationDate'
            Friendly = 'Account Expiration Date'
            Category = 'Settings'
            DefaultValue = 'Select Date'
            Type = 'Button'
            RangeUpper = $null
     }
     'Account Not Delegated' = [PSCustomObject]@{
            Actual = 'AccountNotDelegated'
            Friendly = 'Account Not Delegated'
            Category = 'Settings'
            DefaultValue = $false
            Type = 'Boolean'
            RangeUpper = $null
     }
     'Cannot Change Password' = [PSCustomObject]@{
            Actual = 'CannotChangePassword'
            Friendly = 'Cannot Change Password'
            Category = 'Settings'
            DefaultValue = $false
            Type = 'Boolean'
            RangeUpper = $null
     }
     'Change Password at Logon' = [PSCustomObject]@{
            Actual = 'ChangePasswordAtLogon'
            Friendly = 'Change Password at Logon'
            Category = 'Settings'
            DefaultValue = $false
            Type = 'Boolean'
            RangeUpper = $null
     }
     'City' = [PSCustomObject]@{
            Actual = 'City'
            Friendly = 'City'
            Category = 'Contact'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 64
     }
     'Company' = [PSCustomObject]@{
            Actual = 'Company'
            Friendly = 'Company'
            Category = 'Contact'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 64
     }
     <#'Country' = [PSCustomObject]@{
            Actual = 'Country'
            Friendly = 'Country'
            Category = 'Contact'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = $null
     }#>
     'Department' = [PSCustomObject]@{
            Actual = 'Department'
            Friendly = 'Department'
            Category = 'Contact'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 64
     }
     'Description' = [PSCustomObject]@{
            Actual = 'Description'
            Friendly = 'Description'
            Category = 'General'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 1024
     }
     'Display Name' = [PSCustomObject]@{
            Actual = 'DisplayName'
            Friendly = 'Display Name'
            Category = 'General'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 256
     }
     'Division' = [PSCustomObject]@{
            Actual = 'Division'
            Friendly = 'Division'
            Category = 'Contact'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 256
     }
     'Email Address' = [PSCustomObject]@{
            Actual = 'EmailAddress'
            Friendly = 'Email Address'
            Category = 'Contact'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 256
     }
     'Enabled' = [PSCustomObject]@{
            Actual = 'Enabled'
            Friendly = 'Enabled'
            Category = 'Settings'
            DefaultValue = $true
            Type = 'Boolean'
            RangeUpper = $null
     }
     'Fax' = [PSCustomObject]@{
            Actual = 'Fax'
            Friendly = 'Fax'
            Category = 'Contact'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 64
     }
     'First Name' = [PSCustomObject]@{
            Actual = 'GivenName'
            Friendly = 'First Name'
            Category = 'General'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 64
     }
     'Logon Workstations' = [PSCustomObject]@{
            Actual = 'LogonWorkstations'
            Friendly = 'Logon Workstations'
            Category = 'General'
            DefaultValue = 'Select Workstations'
            Type = 'Button'
            RangeUpper = $null
     }
     'Home Phone' = [PSCustomObject]@{
            Actual = 'HomePhone'
            Friendly = 'Home Phone'
            Category = 'Contact'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 64
     }
     'Initials' = [PSCustomObject]@{
            Actual = 'Initials'
            Friendly = 'Initials'
            Category = 'General'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 6
     }
     'Last Name' = [PSCustomObject]@{
            Actual = 'Surname'
            Friendly = 'Last Name'
            Category = 'General'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 64
     }
     'Manager' = [PSCustomObject]@{
            Actual = 'Manager'
            Friendly = 'Manager'
            Category = 'Contact'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = $null
     }
     'Security Groups' = [PSCustomObject]@{
            Actual = 'MemberOf'
            Friendly = 'Security Groups'
            Category = 'General'
            DefaultValue = 'Select Groups'
            Type = 'Button'
            RangeUpper = $null
     }
     'Mobile Phone' = [PSCustomObject]@{
            Actual = 'MobilePhone'
            Friendly = 'Mobile Phone'
            Category = 'Contact'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 64
     }
     'Full Name' = [PSCustomObject]@{
            Actual = 'Name'
            Friendly = 'Full Name'
            Category = 'General'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 256
     }
     'Office Phone' = [PSCustomObject]@{
            Actual = 'OfficePhone'
            Friendly = 'Office Phone'
            Category = 'Contact'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 64
     }
     'Organization' = [PSCustomObject]@{
            Actual = 'Organization'
            Friendly = 'Organization'
            Category = 'Contact'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 64
     }
     'Office' = [PSCustomObject]@{
            Actual = 'Office'
            Friendly = 'Office'
            Category = 'Contact'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 128
     }
     'Password Never Expires' = [PSCustomObject]@{
            Actual = 'PasswordNeverExpires'
            Friendly = 'Password Never Expires'
            Category = 'Settings'
            DefaultValue = $false
            Type = 'Boolean'
            RangeUpper = $null
     }
     'P.O. Box' = [PSCustomObject]@{
            Actual = 'POBox'
            Friendly = 'P.O. Box'
            Category = 'Contact'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 40
     }
     'Postal Code' = [PSCustomObject]@{
            Actual = 'PostalCode'
            Friendly = 'Postal Code'
            Category = 'Contact'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 40
     }
     'Password Not Required' = [PSCustomObject]@{
            Actual = 'PasswordNotRequired'
            Friendly = 'Password Not Required'
            Category = 'Settings'
            DefaultValue = $false
            Type = 'Boolean'
            RangeUpper = $null
     }
     'State or Province' = [PSCustomObject]@{
            Actual = 'State'
            Friendly = 'State or Province'
            Category = 'Contact'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 128
     }
     'Street Address' = [PSCustomObject]@{
            Actual = 'StreetAddress'
            Friendly = 'Street Address'
            Category = 'Contact'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 1024
     }
     'Title' = [PSCustomObject]@{
            Actual = 'Title'
            Friendly = 'Title'
            Category = 'Contact'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 128
     }
     <#'Organizational Unit' = [PSCustomObject]@{
            Actual = 'Path'
            Friendly = 'Organizational Unit'
            Category = 'General'
            DefaultValue = 'Select OU'
            Type = 'Button'
            RangeUpper = $null
     }#>
     'User Principal Name' = [PSCustomObject]@{
            Actual = 'UserPrincipalName'
            Friendly = 'User Principal Name'
            Category = 'General'
            DefaultValue = $null
            Type = 'Textbox'
            RangeUpper = 1024
     }
}

$Global:inverseData = @{
    'Cannot Change Password' = 'Change Password at Logon'
    'Change Password at Logon' = 'Cannot Change Password'
    'Password Not Required' = 'Account Password'
}
#endregion dictionaries


#endregion GlobalFunctions


############################################################################################################










############################################################################################################
#region Designers

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
New-Object -TypeName System.Windows.Forms.Form | Out-Null
[System.Windows.Forms.Application]::EnableVisualStyles();


############################################################################################################
#region Main Designer
$MainForm = New-Object -TypeName System.Windows.Forms.Form
[System.Windows.Forms.DataGridView]$datagridMainUser = $null
[System.Windows.Forms.Button]$bMainEditColumns = $null
[System.Windows.Forms.Button]$bMainImportCSV = $null
[System.Windows.Forms.Button]$bMainNext = $null
[System.Windows.Forms.Button]$bMainValidate = $null
[System.Windows.Forms.Button]$bMainAddRows = $null
[System.Windows.Forms.Button]$bMainLoadPreset = $null
[System.Windows.Forms.Button]$bMainSavePreset = $null
[System.Windows.Forms.OpenFileDialog]$openFileDialog = $null
[System.Windows.Forms.Button]$bMainClearSheet = $null
[System.Windows.Forms.SaveFileDialog]$saveFileDialog = $null
function InitializeComponent
{
[System.Windows.Forms.DataGridViewCellStyle]$DataGridViewCellStyle11 = (New-Object -TypeName System.Windows.Forms.DataGridViewCellStyle)
$datagridMainUser = (New-Object -TypeName System.Windows.Forms.DataGridView)
$bMainEditColumns = (New-Object -TypeName System.Windows.Forms.Button)
$bMainImportCSV = (New-Object -TypeName System.Windows.Forms.Button)
$bMainNext = (New-Object -TypeName System.Windows.Forms.Button)
$bMainValidate = (New-Object -TypeName System.Windows.Forms.Button)
$bMainAddRows = (New-Object -TypeName System.Windows.Forms.Button)
$bMainLoadPreset = (New-Object -TypeName System.Windows.Forms.Button)
$bMainSavePreset = (New-Object -TypeName System.Windows.Forms.Button)
$openFileDialog = (New-Object -TypeName System.Windows.Forms.OpenFileDialog)
$bMainClearSheet = (New-Object -TypeName System.Windows.Forms.Button)
$saveFileDialog = (New-Object -TypeName System.Windows.Forms.SaveFileDialog)
([System.ComponentModel.ISupportInitialize]$datagridMainUser).BeginInit()
$MainForm.SuspendLayout()
#
#datagridMainUser
#
$datagridMainUser.AllowUserToAddRows = $false
$datagridMainUser.AllowUserToResizeColumns = $false
$DataGridViewCellStyle11.BackColor = [System.Drawing.Color]::White
$datagridMainUser.AlternatingRowsDefaultCellStyle = $DataGridViewCellStyle11
$datagridMainUser.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
$datagridMainUser.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
$datagridMainUser.CellBorderStyle = [System.Windows.Forms.DataGridViewCellBorderStyle]::Sunken
$datagridMainUser.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::AutoSize
$datagridMainUser.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]100,[System.Int32]12))
$datagridMainUser.Name = [System.String]'datagridMainUser'
$datagridMainUser.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]820,[System.Int32]580))
$datagridMainUser.TabIndex = [System.Int32]0
$datagridMainUser.add_CellContentClick($datagridMainUser_CellContentClick)
$datagridMainUser.add_CellValueChanged($datagridMainUser_CellValueChanged)
$datagridMainUser.add_DefaultValuesNeeded($datagridMainUser_DefaultValuesNeeded)
#
#bMainEditColumns
#
$bMainEditColumns.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]12))
$bMainEditColumns.Name = [System.String]'bMainEditColumns'
$bMainEditColumns.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]82,[System.Int32]23))
$bMainEditColumns.TabIndex = [System.Int32]1
$bMainEditColumns.Text = [System.String]'Edit Columns'
$bMainEditColumns.UseVisualStyleBackColor = $true
$bMainEditColumns.add_Click($bMainEditColumns_Click)
#
#bMainImportCSV
#
$bMainImportCSV.BackColor = [System.Drawing.SystemColors]::Control
$bMainImportCSV.Font = (New-Object -TypeName System.Drawing.Font -ArgumentList @([System.String]'Tahoma',[System.Single]8.25))
$bMainImportCSV.ForeColor = [System.Drawing.Color]::FromArgb(([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)))

$bMainImportCSV.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]150))
$bMainImportCSV.Name = [System.String]'bMainImportCSV'
$bMainImportCSV.RightToLeft = [System.Windows.Forms.RightToLeft]::No
$bMainImportCSV.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]82,[System.Int32]23))
$bMainImportCSV.TabIndex = [System.Int32]5
$bMainImportCSV.Text = [System.String]'Import CSV'
$bMainImportCSV.UseVisualStyleBackColor = $true
$bMainImportCSV.add_Click($bMainImportCSV_Click)
#
#bMainNext
#
$bMainNext.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right)
$bMainNext.BackColor = [System.Drawing.SystemColors]::Control
$bMainNext.Enabled = $false
$bMainNext.Font = (New-Object -TypeName System.Drawing.Font -ArgumentList @([System.String]'Tahoma',[System.Single]8.25))
$bMainNext.ForeColor = [System.Drawing.Color]::FromArgb(([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)))

$bMainNext.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]842,[System.Int32]598))
$bMainNext.Name = [System.String]'bMainNext'
$bMainNext.RightToLeft = [System.Windows.Forms.RightToLeft]::No
$bMainNext.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]78,[System.Int32]23))
$bMainNext.TabIndex = [System.Int32]8
$bMainNext.Text = [System.String]'Create'
$bMainNext.UseVisualStyleBackColor = $true
$bMainNext.add_Click($bMainNext_Click)
#
#bMainValidate
#
$bMainValidate.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right)
$bMainValidate.BackColor = [System.Drawing.SystemColors]::Control
$bMainValidate.Font = (New-Object -TypeName System.Drawing.Font -ArgumentList @([System.String]'Tahoma',[System.Single]8.25))
$bMainValidate.ForeColor = [System.Drawing.Color]::FromArgb(([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)))

$bMainValidate.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]758,[System.Int32]598))
$bMainValidate.Name = [System.String]'bMainValidate'
$bMainValidate.RightToLeft = [System.Windows.Forms.RightToLeft]::No
$bMainValidate.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]78,[System.Int32]23))
$bMainValidate.TabIndex = [System.Int32]7
$bMainValidate.Text = [System.String]'Validate'
$bMainValidate.UseVisualStyleBackColor = $true
$bMainValidate.add_Click($bMainValidate_Click)
#
#bMainAddRows
#
$bMainAddRows.BackColor = [System.Drawing.SystemColors]::Control
$bMainAddRows.Font = (New-Object -TypeName System.Drawing.Font -ArgumentList @([System.String]'Tahoma',[System.Single]8.25))
$bMainAddRows.ForeColor = [System.Drawing.Color]::FromArgb(([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)))

$bMainAddRows.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]41))
$bMainAddRows.Name = [System.String]'bMainAddRows'
$bMainAddRows.RightToLeft = [System.Windows.Forms.RightToLeft]::No
$bMainAddRows.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]82,[System.Int32]23))
$bMainAddRows.TabIndex = [System.Int32]2
$bMainAddRows.Text = [System.String]'Add Rows'
$bMainAddRows.UseVisualStyleBackColor = $true
$bMainAddRows.add_Click($bMainAddRows_Click)
#
#bMainLoadPreset
#
$bMainLoadPreset.BackColor = [System.Drawing.SystemColors]::Control
$bMainLoadPreset.Font = (New-Object -TypeName System.Drawing.Font -ArgumentList @([System.String]'Tahoma',[System.Single]8.25))
$bMainLoadPreset.ForeColor = [System.Drawing.Color]::FromArgb(([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)))

$bMainLoadPreset.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]92))
$bMainLoadPreset.Name = [System.String]'bMainLoadPreset'
$bMainLoadPreset.RightToLeft = [System.Windows.Forms.RightToLeft]::No
$bMainLoadPreset.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]82,[System.Int32]23))
$bMainLoadPreset.TabIndex = [System.Int32]3
$bMainLoadPreset.Text = [System.String]'Load Preset'
$bMainLoadPreset.UseVisualStyleBackColor = $true
$bMainLoadPreset.add_Click($bMainLoadPreset_Click)
#
#bMainSavePreset
#
$bMainSavePreset.BackColor = [System.Drawing.SystemColors]::Control
$bMainSavePreset.Font = (New-Object -TypeName System.Drawing.Font -ArgumentList @([System.String]'Tahoma',[System.Single]8.25))
$bMainSavePreset.ForeColor = [System.Drawing.Color]::FromArgb(([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)))

$bMainSavePreset.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]121))
$bMainSavePreset.Name = [System.String]'bMainSavePreset'
$bMainSavePreset.RightToLeft = [System.Windows.Forms.RightToLeft]::No
$bMainSavePreset.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]82,[System.Int32]23))
$bMainSavePreset.TabIndex = [System.Int32]4
$bMainSavePreset.Text = [System.String]'Save Preset'
$bMainSavePreset.UseVisualStyleBackColor = $true
$bMainSavePreset.add_Click($bMainSavePreset_Click)
#
#openFileDialog
#
$openFileDialog.Filter = [System.String]'CSV Files (*.csv)|*.csv'
#
#bMainClearSheet
#
$bMainClearSheet.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left)
$bMainClearSheet.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]569))
$bMainClearSheet.Name = [System.String]'bMainClearSheet'
$bMainClearSheet.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]82,[System.Int32]23))
$bMainClearSheet.TabIndex = [System.Int32]6
$bMainClearSheet.Text = [System.String]'Clear Sheet'
$bMainClearSheet.UseVisualStyleBackColor = $true
$bMainClearSheet.add_Click($bMainClearSheet_Click)
#
#saveFileDialog
#
$saveFileDialog.CreatePrompt = $true
$saveFileDialog.DefaultExt = [System.String]'CSV Files (*.csv)|*.csv'
$saveFileDialog.Filter = [System.String]'CSV Files (*.csv)|*.csv'
$saveFileDialog.InitialDirectory = [System.String]'Desktop'
$saveFileDialog.Title = [System.String]'Save Preset'
#
#MainForm
#
$MainForm.ClientSize = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]932,[System.Int32]624))
$MainForm.Controls.Add($bMainClearSheet)
$MainForm.Controls.Add($bMainEditColumns)
$MainForm.Controls.Add($datagridMainUser)
$MainForm.Controls.Add($bMainImportCSV)
$MainForm.Controls.Add($bMainNext)
$MainForm.Controls.Add($bMainValidate)
$MainForm.Controls.Add($bMainAddRows)
$MainForm.Controls.Add($bMainLoadPreset)
$MainForm.Controls.Add($bMainSavePreset)
$MainForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$MainForm.Text = [System.String]'Active Directory Bulk User Creator'
$MainForm.add_Load($MainForm_Load)
([System.ComponentModel.ISupportInitialize]$datagridMainUser).EndInit()
$MainForm.ResumeLayout($false)
Add-Member -InputObject $MainForm -Name datagridMainUser -Value $datagridMainUser -MemberType NoteProperty
Add-Member -InputObject $MainForm -Name bMainEditColumns -Value $bMainEditColumns -MemberType NoteProperty
Add-Member -InputObject $MainForm -Name bMainImportCSV -Value $bMainImportCSV -MemberType NoteProperty
Add-Member -InputObject $MainForm -Name bMainNext -Value $bMainNext -MemberType NoteProperty
Add-Member -InputObject $MainForm -Name bMainValidate -Value $bMainValidate -MemberType NoteProperty
Add-Member -InputObject $MainForm -Name bMainAddRows -Value $bMainAddRows -MemberType NoteProperty
Add-Member -InputObject $MainForm -Name bMainLoadPreset -Value $bMainLoadPreset -MemberType NoteProperty
Add-Member -InputObject $MainForm -Name bMainSavePreset -Value $bMainSavePreset -MemberType NoteProperty
Add-Member -InputObject $MainForm -Name openFileDialog -Value $openFileDialog -MemberType NoteProperty
Add-Member -InputObject $MainForm -Name bMainClearSheet -Value $bMainClearSheet -MemberType NoteProperty
Add-Member -InputObject $MainForm -Name saveFileDialog -Value $saveFileDialog -MemberType NoteProperty
}
. InitializeComponent
#endregion Main Designer



############################################################################################################
#region AddRows Designer
$FormAddRows = New-Object -TypeName System.Windows.Forms.Form
[System.Windows.Forms.NumericUpDown]$nudAddRows = $null
[System.Windows.Forms.Label]$lAddRows = $null
[System.Windows.Forms.Button]$bAddRowsCancel = $null
[System.Windows.Forms.Button]$bAddRowsOK = $null
function InitializeComponent
{
$nudAddRows = (New-Object -TypeName System.Windows.Forms.NumericUpDown)
$lAddRows = (New-Object -TypeName System.Windows.Forms.Label)
$bAddRowsCancel = (New-Object -TypeName System.Windows.Forms.Button)
$bAddRowsOK = (New-Object -TypeName System.Windows.Forms.Button)
([System.ComponentModel.ISupportInitialize]$nudAddRows).BeginInit()
$FormAddRows.SuspendLayout()
#
#nudAddRows
#
$nudAddRows.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]234,[System.Int32]9))
$nudAddRows.Minimum = [System.Int32]1
$nudAddRows.Name = [System.String]'nudAddRows'
$nudAddRows.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]109,[System.Int32]21))
$nudAddRows.TabIndex = [System.Int32]0
$nudAddRows.Value = [System.Int32]1
$nudAddRows.add_ValueChanged($nudAddRows_ValueChanged)
#
#lAddRows
#
$lAddRows.ImageAlign = [System.Drawing.ContentAlignment]::BottomCenter
$lAddRows.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]11))
$lAddRows.Name = [System.String]'lAddRows'
$lAddRows.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]218,[System.Int32]21))
$lAddRows.TabIndex = [System.Int32]1
$lAddRows.Text = [System.String]'Enter the number of rows you want to add:'
#
#bAddRowsCancel
#
$bAddRowsCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$bAddRowsCancel.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]187,[System.Int32]49))
$bAddRowsCancel.Name = [System.String]'bAddRowsCancel'
$bAddRowsCancel.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]75,[System.Int32]23))
$bAddRowsCancel.TabIndex = [System.Int32]1
$bAddRowsCancel.Text = [System.String]'Cancel'
$bAddRowsCancel.UseVisualStyleBackColor = $true
$bAddRowsCancel.add_Click($bAddRowsCancel_Click)
#
#bAddRowsOK
#
$bAddRowsOK.BackColor = [System.Drawing.SystemColors]::Control
$bAddRowsOK.Font = (New-Object -TypeName System.Drawing.Font -ArgumentList @([System.String]'Tahoma',[System.Single]8.25))
$bAddRowsOK.ForeColor = [System.Drawing.Color]::FromArgb(([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)))

$bAddRowsOK.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]268,[System.Int32]49))
$bAddRowsOK.Name = [System.String]'bAddRowsOK'
$bAddRowsOK.RightToLeft = [System.Windows.Forms.RightToLeft]::No
$bAddRowsOK.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]75,[System.Int32]23))
$bAddRowsOK.TabIndex = [System.Int32]2
$bAddRowsOK.Text = [System.String]'OK'
$bAddRowsOK.UseVisualStyleBackColor = $true
$bAddRowsOK.add_Click($bAddRowsOK_Click)
#
#FormAddRows
#
$FormAddRows.AcceptButton = $bAddRowsOK
$FormAddRows.CancelButton = $bAddRowsCancel
$FormAddRows.ClientSize = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]355,[System.Int32]80))
$FormAddRows.Controls.Add($bAddRowsCancel)
$FormAddRows.Controls.Add($lAddRows)
$FormAddRows.Controls.Add($nudAddRows)
$FormAddRows.Controls.Add($bAddRowsOK)
$FormAddRows.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$FormAddRows.MaximizeBox = $false
$FormAddRows.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
$FormAddRows.Text = [System.String]'Add Rows'
$FormAddRows.TopMost = $true
$FormAddRows.add_Load($FormAddRows_Load)
([System.ComponentModel.ISupportInitialize]$nudAddRows).EndInit()
$FormAddRows.ResumeLayout($false)
Add-Member -InputObject $FormAddRows -Name nudAddRows -Value $nudAddRows -MemberType NoteProperty
Add-Member -InputObject $FormAddRows -Name lAddRows -Value $lAddRows -MemberType NoteProperty
Add-Member -InputObject $FormAddRows -Name bAddRowsCancel -Value $bAddRowsCancel -MemberType NoteProperty
Add-Member -InputObject $FormAddRows -Name bAddRowsOK -Value $bAddRowsOK -MemberType NoteProperty
}
. InitializeComponent
#endregion AddRows Designer



############################################################################################################
#region EditColumns Designer
$FormEditColumns = New-Object -TypeName System.Windows.Forms.Form
[System.Windows.Forms.Button]$bEditColumnsAdd = $null
[System.Windows.Forms.Button]$bEditColumnsRemove = $null
[System.Windows.Forms.Button]$bEditColumnsDown = $null
[System.Windows.Forms.Button]$bEditColumnsUp = $null
[System.Windows.Forms.Button]$bEditColumnsCancel = $null
[System.Windows.Forms.Button]$bEditColumnsOK = $null
[System.Windows.Forms.ListView]$listEditColumnsAvailable = $null
[System.Windows.Forms.ListView]$listEditColumnsSelected = $null
[System.Windows.Forms.ColumnHeader]$ColumnHeader1 = $null
function InitializeComponent
{
[System.Windows.Forms.ListViewGroup]$ListViewGroup11 = (New-Object -TypeName System.Windows.Forms.ListViewGroup -ArgumentList @([System.String]'General',[System.Windows.Forms.HorizontalAlignment]::Left))
[System.Windows.Forms.ListViewGroup]$ListViewGroup12 = (New-Object -TypeName System.Windows.Forms.ListViewGroup -ArgumentList @([System.String]'Settings',[System.Windows.Forms.HorizontalAlignment]::Left))
[System.Windows.Forms.ListViewGroup]$ListViewGroup13 = (New-Object -TypeName System.Windows.Forms.ListViewGroup -ArgumentList @([System.String]'Contact',[System.Windows.Forms.HorizontalAlignment]::Left))
[System.Windows.Forms.ListViewGroup]$ListViewGroup14 = (New-Object -TypeName System.Windows.Forms.ListViewGroup -ArgumentList @([System.String]'General',[System.Windows.Forms.HorizontalAlignment]::Left))
[System.Windows.Forms.ListViewGroup]$ListViewGroup15 = (New-Object -TypeName System.Windows.Forms.ListViewGroup -ArgumentList @([System.String]'Settings',[System.Windows.Forms.HorizontalAlignment]::Left))
[System.Windows.Forms.ListViewGroup]$ListViewGroup16 = (New-Object -TypeName System.Windows.Forms.ListViewGroup -ArgumentList @([System.String]'Contact',[System.Windows.Forms.HorizontalAlignment]::Left))
$bEditColumnsAdd = (New-Object -TypeName System.Windows.Forms.Button)
$bEditColumnsRemove = (New-Object -TypeName System.Windows.Forms.Button)
$bEditColumnsDown = (New-Object -TypeName System.Windows.Forms.Button)
$bEditColumnsUp = (New-Object -TypeName System.Windows.Forms.Button)
$bEditColumnsCancel = (New-Object -TypeName System.Windows.Forms.Button)
$bEditColumnsOK = (New-Object -TypeName System.Windows.Forms.Button)
$listEditColumnsAvailable = (New-Object -TypeName System.Windows.Forms.ListView)
$listEditColumnsSelected = (New-Object -TypeName System.Windows.Forms.ListView)
$ColumnHeader1 = (New-Object -TypeName System.Windows.Forms.ColumnHeader)
$FormEditColumns.SuspendLayout()
#
#bEditColumnsAdd
#
$bEditColumnsAdd.Anchor = [System.Windows.Forms.AnchorStyles]::Left
$bEditColumnsAdd.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]182,[System.Int32]124))
$bEditColumnsAdd.Name = [System.String]'bEditColumnsAdd'
$bEditColumnsAdd.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]30,[System.Int32]23))
$bEditColumnsAdd.TabIndex = [System.Int32]1
$bEditColumnsAdd.UseVisualStyleBackColor = $true
$bEditColumnsAdd.add_Click($bEditColumnsAdd_Click)
#
#bEditColumnsRemove
#
$bEditColumnsRemove.Anchor = [System.Windows.Forms.AnchorStyles]::Left
$bEditColumnsRemove.BackColor = [System.Drawing.SystemColors]::Control
$bEditColumnsRemove.Font = (New-Object -TypeName System.Drawing.Font -ArgumentList @([System.String]'Tahoma',[System.Single]8.25,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Point,([System.Byte][System.Byte]0)))
$bEditColumnsRemove.ForeColor = [System.Drawing.Color]::FromArgb(([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)))

$bEditColumnsRemove.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]182,[System.Int32]153))
$bEditColumnsRemove.Name = [System.String]'bEditColumnsRemove'
$bEditColumnsRemove.RightToLeft = [System.Windows.Forms.RightToLeft]::No
$bEditColumnsRemove.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]30,[System.Int32]23))
$bEditColumnsRemove.TabIndex = [System.Int32]2
$bEditColumnsRemove.UseVisualStyleBackColor = $true
$bEditColumnsRemove.add_Click($bEditColumnsRemove_Click)
#
#bEditColumnsDown
#
$bEditColumnsDown.Anchor = [System.Windows.Forms.AnchorStyles]::Left
$bEditColumnsDown.BackColor = [System.Drawing.SystemColors]::Control
$bEditColumnsDown.Font = (New-Object -TypeName System.Drawing.Font -ArgumentList @([System.String]'Tahoma',[System.Single]9.75,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Point,([System.Byte][System.Byte]0)))
$bEditColumnsDown.ForeColor = [System.Drawing.Color]::FromArgb(([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)))

$bEditColumnsDown.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]388,[System.Int32]153))
$bEditColumnsDown.Name = [System.String]'bEditColumnsDown'
$bEditColumnsDown.RightToLeft = [System.Windows.Forms.RightToLeft]::No
$bEditColumnsDown.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]23,[System.Int32]23))
$bEditColumnsDown.TabIndex = [System.Int32]5
$bEditColumnsDown.UseVisualStyleBackColor = $true
$bEditColumnsDown.add_Click($bEditColumnsDown_Click)
#
#bEditColumnsUp
#
$bEditColumnsUp.Anchor = [System.Windows.Forms.AnchorStyles]::Left
$bEditColumnsUp.BackColor = [System.Drawing.SystemColors]::Control
$bEditColumnsUp.Font = (New-Object -TypeName System.Drawing.Font -ArgumentList @([System.String]'Tahoma',[System.Single]9.75,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Point,([System.Byte][System.Byte]0)))
$bEditColumnsUp.ForeColor = [System.Drawing.Color]::FromArgb(([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)))

$bEditColumnsUp.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]388,[System.Int32]124))
$bEditColumnsUp.Name = [System.String]'bEditColumnsUp'
$bEditColumnsUp.RightToLeft = [System.Windows.Forms.RightToLeft]::No
$bEditColumnsUp.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]23,[System.Int32]23))
$bEditColumnsUp.TabIndex = [System.Int32]4
$bEditColumnsUp.UseVisualStyleBackColor = $true
$bEditColumnsUp.add_Click($bEditColumnsUp_Click)
#
#bEditColumnsCancel
#
$bEditColumnsCancel.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right)
$bEditColumnsCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$bEditColumnsCancel.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]262,[System.Int32]319))
$bEditColumnsCancel.Name = [System.String]'bEditColumnsCancel'
$bEditColumnsCancel.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]74,[System.Int32]23))
$bEditColumnsCancel.TabIndex = [System.Int32]6
$bEditColumnsCancel.Text = [System.String]'Cancel'
$bEditColumnsCancel.UseVisualStyleBackColor = $true
$bEditColumnsCancel.add_Click($bEditColumnsCancel_Click)
#
#bEditColumnsOK
#
$bEditColumnsOK.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right)
$bEditColumnsOK.BackColor = [System.Drawing.SystemColors]::Control
$bEditColumnsOK.Font = (New-Object -TypeName System.Drawing.Font -ArgumentList @([System.String]'Tahoma',[System.Single]8.25))
$bEditColumnsOK.ForeColor = [System.Drawing.Color]::FromArgb(([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)))

$bEditColumnsOK.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]342,[System.Int32]319))
$bEditColumnsOK.Name = [System.String]'bEditColumnsOK'
$bEditColumnsOK.RightToLeft = [System.Windows.Forms.RightToLeft]::No
$bEditColumnsOK.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]69,[System.Int32]23))
$bEditColumnsOK.TabIndex = [System.Int32]7
$bEditColumnsOK.Text = [System.String]'OK'
$bEditColumnsOK.UseVisualStyleBackColor = $true
$bEditColumnsOK.add_Click($bEditColumnsOK_Click)
#
#listEditColumnsAvailable
#
$listEditColumnsAvailable.Alignment = [System.Windows.Forms.ListViewAlignment]::Default
$listEditColumnsAvailable.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left)
$listEditColumnsAvailable.GridLines = $true
$ListViewGroup11.Header = [System.String]'General'
$ListViewGroup11.Name = [System.String]'General'
$ListViewGroup12.Header = [System.String]'Settings'
$ListViewGroup12.Name = [System.String]'Settings'
$ListViewGroup13.Header = [System.String]'Contact'
$ListViewGroup13.Name = [System.String]'Contact'
$listEditColumnsAvailable.Groups.AddRange([System.Windows.Forms.ListViewGroup[]]@($ListViewGroup11,$ListViewGroup12,$ListViewGroup13))
$listEditColumnsAvailable.LabelWrap = $false
$listEditColumnsAvailable.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]12))
$listEditColumnsAvailable.Name = [System.String]'listEditColumnsAvailable'
$listEditColumnsAvailable.RightToLeft = [System.Windows.Forms.RightToLeft]::No
$listEditColumnsAvailable.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]164,[System.Int32]289))
$listEditColumnsAvailable.Sorting = [System.Windows.Forms.SortOrder]::Ascending
$listEditColumnsAvailable.TabIndex = [System.Int32]0
$listEditColumnsAvailable.UseCompatibleStateImageBehavior = $false
$listEditColumnsAvailable.View = [System.Windows.Forms.View]::SmallIcon
$listEditColumnsAvailable.add_SelectedIndexChanged($listEditColumnsAvailable_SelectedIndexChanged)
$listEditColumnsAvailable.add_DoubleClick($bEditColumnsAdd_Click)
#
#listEditColumnsSelected
#
$listEditColumnsSelected.Alignment = [System.Windows.Forms.ListViewAlignment]::Default
$listEditColumnsSelected.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left)
$listEditColumnsSelected.BackColor = [System.Drawing.SystemColors]::Window
$listEditColumnsSelected.Columns.AddRange([System.Windows.Forms.ColumnHeader[]]@($ColumnHeader1))
$listEditColumnsSelected.Font = (New-Object -TypeName System.Drawing.Font -ArgumentList @([System.String]'Tahoma',[System.Single]8.25))
$listEditColumnsSelected.ForeColor = [System.Drawing.SystemColors]::WindowText
$ListViewGroup14.Header = [System.String]'General'
$ListViewGroup14.Name = [System.String]'General'
$ListViewGroup15.Header = [System.String]'Settings'
$ListViewGroup15.Name = [System.String]'Settings'
$ListViewGroup16.Header = [System.String]'Contact'
$ListViewGroup16.Name = [System.String]'Contact'
$listEditColumnsSelected.Groups.AddRange([System.Windows.Forms.ListViewGroup[]]@($ListViewGroup14,$ListViewGroup15,$ListViewGroup16))
$listEditColumnsSelected.HeaderStyle = [System.Windows.Forms.ColumnHeaderStyle]::None
$listEditColumnsSelected.HideSelection = $false
$listEditColumnsSelected.ImeMode = [System.Windows.Forms.ImeMode]::NoControl
$listEditColumnsSelected.LabelWrap = $false
$listEditColumnsSelected.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]218,[System.Int32]12))
$listEditColumnsSelected.Name = [System.String]'listEditColumnsSelected'
$listEditColumnsSelected.RightToLeft = [System.Windows.Forms.RightToLeft]::No
$listEditColumnsSelected.ShowGroups = $false
$listEditColumnsSelected.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]164,[System.Int32]289))
$listEditColumnsSelected.TabIndex = [System.Int32]3
$listEditColumnsSelected.UseCompatibleStateImageBehavior = $false
$listEditColumnsSelected.View = [System.Windows.Forms.View]::Details
$listEditColumnsSelected.add_SelectedIndexChanged($listEditColumnsSelected_SelectedIndexChanged)
$listEditColumnsSelected.add_DoubleClick($bEditColumnsRemove_Click)
#
#ColumnHeader1
#
$ColumnHeader1.Width = [System.Int32]200
#
#FormEditColumns
#
$FormEditColumns.AcceptButton = $bEditColumnsOK
$FormEditColumns.CancelButton = $bEditColumnsCancel
$FormEditColumns.ClientSize = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]418,[System.Int32]345))
$FormEditColumns.ControlBox = $false
$FormEditColumns.Controls.Add($listEditColumnsAvailable)
$FormEditColumns.Controls.Add($bEditColumnsCancel)
$FormEditColumns.Controls.Add($bEditColumnsAdd)
$FormEditColumns.Controls.Add($bEditColumnsRemove)
$FormEditColumns.Controls.Add($bEditColumnsDown)
$FormEditColumns.Controls.Add($bEditColumnsUp)
$FormEditColumns.Controls.Add($bEditColumnsOK)
$FormEditColumns.Controls.Add($listEditColumnsSelected)
$FormEditColumns.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$FormEditColumns.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
$FormEditColumns.Text = [System.String]'Edit Columns'
$FormEditColumns.add_Load($FormEditColumns_Load)
$FormEditColumns.ResumeLayout($false)
Add-Member -InputObject $FormEditColumns -Name bEditColumnsAdd -Value $bEditColumnsAdd -MemberType NoteProperty
Add-Member -InputObject $FormEditColumns -Name bEditColumnsRemove -Value $bEditColumnsRemove -MemberType NoteProperty
Add-Member -InputObject $FormEditColumns -Name bEditColumnsDown -Value $bEditColumnsDown -MemberType NoteProperty
Add-Member -InputObject $FormEditColumns -Name bEditColumnsUp -Value $bEditColumnsUp -MemberType NoteProperty
Add-Member -InputObject $FormEditColumns -Name bEditColumnsCancel -Value $bEditColumnsCancel -MemberType NoteProperty
Add-Member -InputObject $FormEditColumns -Name bEditColumnsOK -Value $bEditColumnsOK -MemberType NoteProperty
Add-Member -InputObject $FormEditColumns -Name listEditColumnsAvailable -Value $listEditColumnsAvailable -MemberType NoteProperty
Add-Member -InputObject $FormEditColumns -Name listEditColumnsSelected -Value $listEditColumnsSelected -MemberType NoteProperty
Add-Member -InputObject $FormEditColumns -Name ColumnHeader1 -Value $ColumnHeader1 -MemberType NoteProperty
}
. InitializeComponent
#endregion EditColumns Designer



############################################################################################################
#region LogonWorkstations Desiginer
$FormLogonWorkstations = New-Object -TypeName System.Windows.Forms.Form
[System.Windows.Forms.TextBox]$tbLogonWorkstations = $null
[System.Windows.Forms.Button]$bLogonWorkstationsOK = $null
[System.Windows.Forms.Button]$bLogonWorkstationsCancel = $null
[System.Windows.Forms.Button]$bLogonWorkstationsVerify = $null
[System.Windows.Forms.Label]$lLogonWorkstations = $null
[System.Windows.Forms.CheckBox]$cbLogonWorkstations = $null
function InitializeComponent
{
$tbLogonWorkstations = (New-Object -TypeName System.Windows.Forms.TextBox)
$bLogonWorkstationsOK = (New-Object -TypeName System.Windows.Forms.Button)
$bLogonWorkstationsCancel = (New-Object -TypeName System.Windows.Forms.Button)
$bLogonWorkstationsVerify = (New-Object -TypeName System.Windows.Forms.Button)
$lLogonWorkstations = (New-Object -TypeName System.Windows.Forms.Label)
$cbLogonWorkstations = (New-Object -TypeName System.Windows.Forms.CheckBox)
$FormLogonWorkstations.SuspendLayout()
#
#tbLogonWorkstations
#
$tbLogonWorkstations.AcceptsReturn = $true
$tbLogonWorkstations.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]29))
$tbLogonWorkstations.Multiline = $true
$tbLogonWorkstations.Name = [System.String]'tbLogonWorkstations'
$tbLogonWorkstations.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$tbLogonWorkstations.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]161,[System.Int32]245))
$tbLogonWorkstations.TabIndex = [System.Int32]0
$tbLogonWorkstations.add_TextChanged($tbLogonWorkstations_TextChanged)
#
#bLogonWorkstationsOK
#
$bLogonWorkstationsOK.Enabled = $false
$bLogonWorkstationsOK.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]193,[System.Int32]283))
$bLogonWorkstationsOK.Name = [System.String]'bLogonWorkstationsOK'
$bLogonWorkstationsOK.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]75,[System.Int32]23))
$bLogonWorkstationsOK.TabIndex = [System.Int32]4
$bLogonWorkstationsOK.Text = [System.String]'OK'
$bLogonWorkstationsOK.UseVisualStyleBackColor = $true
$bLogonWorkstationsOK.add_Click($bLogonWorkstationsOK_Click)
#
#bLogonWorkstationsCancel
#
$bLogonWorkstationsCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$bLogonWorkstationsCancel.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]115,[System.Int32]283))
$bLogonWorkstationsCancel.Name = [System.String]'bLogonWorkstationsCancel'
$bLogonWorkstationsCancel.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]75,[System.Int32]23))
$bLogonWorkstationsCancel.TabIndex = [System.Int32]3
$bLogonWorkstationsCancel.Text = [System.String]'Cancel'
$bLogonWorkstationsCancel.UseVisualStyleBackColor = $true
$bLogonWorkstationsCancel.add_Click($bLogonWorkstationsCancel_Click)
#
#bLogonWorkstationsVerify
#
$bLogonWorkstationsVerify.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]179,[System.Int32]29))
$bLogonWorkstationsVerify.Name = [System.String]'bLogonWorkstationsVerify'
$bLogonWorkstationsVerify.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]89,[System.Int32]23))
$bLogonWorkstationsVerify.TabIndex = [System.Int32]1
$bLogonWorkstationsVerify.Text = [System.String]'Sort and Verify'
$bLogonWorkstationsVerify.UseVisualStyleBackColor = $true
$bLogonWorkstationsVerify.add_Click($bLogonWorkstationsVerify_Click)
#
#lLogonWorkstations
#
$lLogonWorkstations.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]9))
$lLogonWorkstations.Name = [System.String]'lLogonWorkstations'
$lLogonWorkstations.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]153,[System.Int32]17))
$lLogonWorkstations.TabIndex = [System.Int32]4
$lLogonWorkstations.Text = [System.String]'Add Logon Workstations:'
$lLogonWorkstations.TextAlign = [System.Drawing.ContentAlignment]::BottomLeft
#
#cbLogonWorkstations
#
$cbLogonWorkstations.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]287))
$cbLogonWorkstations.Name = [System.String]'cbLogonWorkstations'
$cbLogonWorkstations.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]97,[System.Int32]19))
$cbLogonWorkstations.TabIndex = [System.Int32]2
$cbLogonWorkstations.Text = [System.String]'All Computers'
$cbLogonWorkstations.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$cbLogonWorkstations.UseVisualStyleBackColor = $true
$cbLogonWorkstations.add_CheckedChanged($cbLogonWorkstations_CheckedChanged)
#
#FormLogonWorkstations
#
$FormLogonWorkstations.AcceptButton = $bLogonWorkstationsOK
$FormLogonWorkstations.CancelButton = $bLogonWorkstationsCancel
$FormLogonWorkstations.ClientSize = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]275,[System.Int32]313))
$FormLogonWorkstations.Controls.Add($cbLogonWorkstations)
$FormLogonWorkstations.Controls.Add($lLogonWorkstations)
$FormLogonWorkstations.Controls.Add($bLogonWorkstationsVerify)
$FormLogonWorkstations.Controls.Add($bLogonWorkstationsCancel)
$FormLogonWorkstations.Controls.Add($bLogonWorkstationsOK)
$FormLogonWorkstations.Controls.Add($tbLogonWorkstations)
$FormLogonWorkstations.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedToolWindow
$FormLogonWorkstations.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
$FormLogonWorkstations.Text = [System.String]'Logon Workstations'
$FormLogonWorkstations.TopMost = $true
$FormLogonWorkstations.add_Load($FormLogonWorkstations_Load)
$FormLogonWorkstations.ResumeLayout($false)
$FormLogonWorkstations.PerformLayout()
Add-Member -InputObject $FormLogonWorkstations -Name tbLogonWorkstations -Value $tbLogonWorkstations -MemberType NoteProperty
Add-Member -InputObject $FormLogonWorkstations -Name bLogonWorkstationsOK -Value $bLogonWorkstationsOK -MemberType NoteProperty
Add-Member -InputObject $FormLogonWorkstations -Name bLogonWorkstationsCancel -Value $bLogonWorkstationsCancel -MemberType NoteProperty
Add-Member -InputObject $FormLogonWorkstations -Name bLogonWorkstationsVerify -Value $bLogonWorkstationsVerify -MemberType NoteProperty
Add-Member -InputObject $FormLogonWorkstations -Name lLogonWorkstations -Value $lLogonWorkstations -MemberType NoteProperty
Add-Member -InputObject $FormLogonWorkstations -Name cbLogonWorkstations -Value $cbLogonWorkstations -MemberType NoteProperty
}
. InitializeComponent
#endregion LogonWorkstations Desiginer



############################################################################################################
#region SecurityGroups Designer
$FormSecurityGroups = New-Object -TypeName System.Windows.Forms.Form
[System.Windows.Forms.TextBox]$tbSecurityGroups = $null
[System.Windows.Forms.Label]$lSecurityGroups = $null
[System.Windows.Forms.Button]$bSecurityGroupsVerify = $null
[System.Windows.Forms.Button]$bSecurityGroupsOK = $null
[System.Windows.Forms.Button]$bSecurityGroupsCancel = $null
[System.Windows.Forms.CheckBox]$cbSecurityGroups = $null
function InitializeComponent
{
$tbSecurityGroups = (New-Object -TypeName System.Windows.Forms.TextBox)
$lSecurityGroups = (New-Object -TypeName System.Windows.Forms.Label)
$bSecurityGroupsVerify = (New-Object -TypeName System.Windows.Forms.Button)
$bSecurityGroupsOK = (New-Object -TypeName System.Windows.Forms.Button)
$bSecurityGroupsCancel = (New-Object -TypeName System.Windows.Forms.Button)
$cbSecurityGroups = (New-Object -TypeName System.Windows.Forms.CheckBox)
$FormSecurityGroups.SuspendLayout()
#
#tbSecurityGroups
#
$tbSecurityGroups.AcceptsReturn = $true
$tbSecurityGroups.BackColor = [System.Drawing.SystemColors]::Window
$tbSecurityGroups.Font = (New-Object -TypeName System.Drawing.Font -ArgumentList @([System.String]'Tahoma',[System.Single]8.25))
$tbSecurityGroups.ForeColor = [System.Drawing.SystemColors]::WindowText
$tbSecurityGroups.ImeMode = [System.Windows.Forms.ImeMode]::NoControl
$tbSecurityGroups.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]29))
$tbSecurityGroups.Multiline = $true
$tbSecurityGroups.Name = [System.String]'tbSecurityGroups'
$tbSecurityGroups.RightToLeft = [System.Windows.Forms.RightToLeft]::No
$tbSecurityGroups.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$tbSecurityGroups.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]154,[System.Int32]245))
$tbSecurityGroups.TabIndex = [System.Int32]0
$tbSecurityGroups.add_TextChanged($tbSecurityGroups_TextChanged)
#
#lSecurityGroups
#
$lSecurityGroups.BackColor = [System.Drawing.SystemColors]::Control
$lSecurityGroups.Font = (New-Object -TypeName System.Drawing.Font -ArgumentList @([System.String]'Tahoma',[System.Single]8.25))
$lSecurityGroups.ForeColor = [System.Drawing.Color]::FromArgb(([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)))

$lSecurityGroups.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]13,[System.Int32]9))
$lSecurityGroups.Name = [System.String]'lSecurityGroups'
$lSecurityGroups.RightToLeft = [System.Windows.Forms.RightToLeft]::No
$lSecurityGroups.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]153,[System.Int32]17))
$lSecurityGroups.TabIndex = [System.Int32]4
$lSecurityGroups.Text = [System.String]'Add Security Groups:'
$lSecurityGroups.TextAlign = [System.Drawing.ContentAlignment]::BottomLeft
#
#bSecurityGroupsVerify
#
$bSecurityGroupsVerify.BackColor = [System.Drawing.SystemColors]::Control
$bSecurityGroupsVerify.Font = (New-Object -TypeName System.Drawing.Font -ArgumentList @([System.String]'Tahoma',[System.Single]8.25))
$bSecurityGroupsVerify.ForeColor = [System.Drawing.Color]::FromArgb(([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)))

$bSecurityGroupsVerify.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]172,[System.Int32]29))
$bSecurityGroupsVerify.Name = [System.String]'bSecurityGroupsVerify'
$bSecurityGroupsVerify.RightToLeft = [System.Windows.Forms.RightToLeft]::No
$bSecurityGroupsVerify.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]89,[System.Int32]23))
$bSecurityGroupsVerify.TabIndex = [System.Int32]1
$bSecurityGroupsVerify.Text = [System.String]'Sort and Verify'
$bSecurityGroupsVerify.UseVisualStyleBackColor = $true
$bSecurityGroupsVerify.add_Click($bSecurityGroupsVerify_Click)
#
#bSecurityGroupsOK
#
$bSecurityGroupsOK.BackColor = [System.Drawing.SystemColors]::Control
$bSecurityGroupsOK.Enabled = $false
$bSecurityGroupsOK.Font = (New-Object -TypeName System.Drawing.Font -ArgumentList @([System.String]'Tahoma',[System.Single]8.25))
$bSecurityGroupsOK.ForeColor = [System.Drawing.Color]::FromArgb(([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)))

$bSecurityGroupsOK.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]186,[System.Int32]280))
$bSecurityGroupsOK.Name = [System.String]'bSecurityGroupsOK'
$bSecurityGroupsOK.RightToLeft = [System.Windows.Forms.RightToLeft]::No
$bSecurityGroupsOK.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]75,[System.Int32]23))
$bSecurityGroupsOK.TabIndex = [System.Int32]4
$bSecurityGroupsOK.Text = [System.String]'OK'
$bSecurityGroupsOK.UseVisualStyleBackColor = $true
$bSecurityGroupsOK.add_Click($bSecurityGroupsOK_Click)
#
#bSecurityGroupsCancel
#
$bSecurityGroupsCancel.BackColor = [System.Drawing.SystemColors]::Control
$bSecurityGroupsCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$bSecurityGroupsCancel.Font = (New-Object -TypeName System.Drawing.Font -ArgumentList @([System.String]'Tahoma',[System.Single]8.25))
$bSecurityGroupsCancel.ForeColor = [System.Drawing.Color]::FromArgb(([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)))

$bSecurityGroupsCancel.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]105,[System.Int32]280))
$bSecurityGroupsCancel.Name = [System.String]'bSecurityGroupsCancel'
$bSecurityGroupsCancel.RightToLeft = [System.Windows.Forms.RightToLeft]::No
$bSecurityGroupsCancel.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]75,[System.Int32]23))
$bSecurityGroupsCancel.TabIndex = [System.Int32]3
$bSecurityGroupsCancel.Text = [System.String]'Cancel'
$bSecurityGroupsCancel.UseVisualStyleBackColor = $true
$bSecurityGroupsCancel.add_Click($bSecurityGroupsCancel_Click)
#
#cbSecurityGroups
#
$cbSecurityGroups.BackColor = [System.Drawing.SystemColors]::Control
$cbSecurityGroups.Font = (New-Object -TypeName System.Drawing.Font -ArgumentList @([System.String]'Tahoma',[System.Single]8.25))
$cbSecurityGroups.ForeColor = [System.Drawing.Color]::FromArgb(([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)))

$cbSecurityGroups.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]280))
$cbSecurityGroups.Name = [System.String]'cbSecurityGroups'
$cbSecurityGroups.RightToLeft = [System.Windows.Forms.RightToLeft]::No
$cbSecurityGroups.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]95,[System.Int32]24))
$cbSecurityGroups.TabIndex = [System.Int32]2
$cbSecurityGroups.Text = [System.String]'No Groups'
$cbSecurityGroups.UseVisualStyleBackColor = $true
$cbSecurityGroups.add_CheckedChanged($cbSecurityGroups_CheckedChanged)
#
#FormSecurityGroups
#
$FormSecurityGroups.AcceptButton = $bSecurityGroupsOK
$FormSecurityGroups.CancelButton = $bSecurityGroupsCancel
$FormSecurityGroups.ClientSize = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]268,[System.Int32]309))
$FormSecurityGroups.Controls.Add($tbSecurityGroups)
$FormSecurityGroups.Controls.Add($lSecurityGroups)
$FormSecurityGroups.Controls.Add($bSecurityGroupsVerify)
$FormSecurityGroups.Controls.Add($bSecurityGroupsOK)
$FormSecurityGroups.Controls.Add($bSecurityGroupsCancel)
$FormSecurityGroups.Controls.Add($cbSecurityGroups)
$FormSecurityGroups.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
$FormSecurityGroups.Text = [System.String]'Security Groups'
$FormSecurityGroups.add_Load($FormSecurityGroups_Load)
$FormSecurityGroups.ResumeLayout($false)
$FormSecurityGroups.PerformLayout()
Add-Member -InputObject $FormSecurityGroups -Name tbSecurityGroups -Value $tbSecurityGroups -MemberType NoteProperty
Add-Member -InputObject $FormSecurityGroups -Name lSecurityGroups -Value $lSecurityGroups -MemberType NoteProperty
Add-Member -InputObject $FormSecurityGroups -Name bSecurityGroupsVerify -Value $bSecurityGroupsVerify -MemberType NoteProperty
Add-Member -InputObject $FormSecurityGroups -Name bSecurityGroupsOK -Value $bSecurityGroupsOK -MemberType NoteProperty
Add-Member -InputObject $FormSecurityGroups -Name bSecurityGroupsCancel -Value $bSecurityGroupsCancel -MemberType NoteProperty
Add-Member -InputObject $FormSecurityGroups -Name cbSecurityGroups -Value $cbSecurityGroups -MemberType NoteProperty
}
. InitializeComponent
#endregion SecurityGroups Designer



############################################################################################################
#region MonthCalendar Designer
$FormExpirationDate = New-Object -TypeName System.Windows.Forms.Form
[System.Windows.Forms.MonthCalendar]$calendarExpirationDate = $null
[System.Windows.Forms.Label]$lExpirationDate = $null
[System.Windows.Forms.Button]$bExpirationDateOK = $null
[System.Windows.Forms.Button]$bExpirationDateCancel = $null
[System.Windows.Forms.CheckBox]$cbExpirationDate = $null
function InitializeComponent
{
$calendarExpirationDate = (New-Object -TypeName System.Windows.Forms.MonthCalendar)
$lExpirationDate = (New-Object -TypeName System.Windows.Forms.Label)
$bExpirationDateOK = (New-Object -TypeName System.Windows.Forms.Button)
$bExpirationDateCancel = (New-Object -TypeName System.Windows.Forms.Button)
$cbExpirationDate = (New-Object -TypeName System.Windows.Forms.CheckBox)
$FormExpirationDate.SuspendLayout()
#
#calendarExpirationDate
#
$calendarExpirationDate.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]34))
$calendarExpirationDate.MaxDate = (New-Object -TypeName System.DateTime -ArgumentList @([System.Int32]2500,[System.Int32]12,[System.Int32]31,[System.Int32]0,[System.Int32]0,[System.Int32]0,[System.Int32]0))
$calendarExpirationDate.MaxSelectionCount = [System.Int32]1
$calendarExpirationDate.MinDate = (New-Object -TypeName System.DateTime -ArgumentList @([System.Int32]2022,[System.Int32]11,[System.Int32]10,[System.Int32]0,[System.Int32]0,[System.Int32]0,[System.Int32]0))
$calendarExpirationDate.Name = [System.String]'calendarExpirationDate'
$calendarExpirationDate.ShowTodayCircle = $false
$calendarExpirationDate.TabIndex = [System.Int32]0
$calendarExpirationDate.TitleBackColor = [System.Drawing.SystemColors]::MenuHighlight
$calendarExpirationDate.TitleForeColor = [System.Drawing.SystemColors]::Highlight
$calendarExpirationDate.TrailingForeColor = [System.Drawing.SystemColors]::MenuHighlight
$calendarExpirationDate.add_DateChanged($calendarExpirationDate_DateChanged)
#
#lExpirationDate
#
$lExpirationDate.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]9))
$lExpirationDate.Name = [System.String]'lExpirationDate'
$lExpirationDate.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]168,[System.Int32]16))
$lExpirationDate.TabIndex = [System.Int32]1
$lExpirationDate.Text = [System.String]'Select Account Expiration Date:'
$lExpirationDate.TextAlign = [System.Drawing.ContentAlignment]::BottomLeft
#
#bExpirationDateOK
#
$bExpirationDateOK.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]164,[System.Int32]225))
$bExpirationDateOK.Name = [System.String]'bExpirationDateOK'
$bExpirationDateOK.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]75,[System.Int32]23))
$bExpirationDateOK.TabIndex = [System.Int32]4
$bExpirationDateOK.Text = [System.String]'OK'
$bExpirationDateOK.UseVisualStyleBackColor = $true
$bExpirationDateOK.add_Click($bExpirationDateOK_Click)
#
#bExpirationDateCancel
#
$bExpirationDateCancel.BackColor = [System.Drawing.SystemColors]::Control
$bExpirationDateCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$bExpirationDateCancel.Font = (New-Object -TypeName System.Drawing.Font -ArgumentList @([System.String]'Tahoma',[System.Single]8.25))
$bExpirationDateCancel.ForeColor = [System.Drawing.Color]::FromArgb(([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)),([System.Int32]([System.Byte][System.Byte]0)))

$bExpirationDateCancel.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]83,[System.Int32]225))
$bExpirationDateCancel.Name = [System.String]'bExpirationDateCancel'
$bExpirationDateCancel.RightToLeft = [System.Windows.Forms.RightToLeft]::No
$bExpirationDateCancel.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]75,[System.Int32]23))
$bExpirationDateCancel.TabIndex = [System.Int32]3
$bExpirationDateCancel.Text = [System.String]'Cancel'
$bExpirationDateCancel.UseVisualStyleBackColor = $true
$bExpirationDateCancel.add_Click($bExpirationDateCancel_Click)
#
#cbExpirationDate
#
$cbExpirationDate.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]195))
$cbExpirationDate.Name = [System.String]'cbExpirationDate'
$cbExpirationDate.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]122,[System.Int32]24))
$cbExpirationDate.TabIndex = [System.Int32]2
$cbExpirationDate.Text = [System.String]'No Expiration Date'
$cbExpirationDate.UseVisualStyleBackColor = $true
$cbExpirationDate.add_CheckedChanged($cbExpirationDate_CheckedChanged)
#
#FormExpirationDate
#
$FormExpirationDate.AcceptButton = $bExpirationDateOK
$FormExpirationDate.CancelButton = $bExpirationDateCancel
$FormExpirationDate.ClientSize = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]251,[System.Int32]250))
$FormExpirationDate.ControlBox = $false
$FormExpirationDate.Controls.Add($cbExpirationDate)
$FormExpirationDate.Controls.Add($bExpirationDateOK)
$FormExpirationDate.Controls.Add($lExpirationDate)
$FormExpirationDate.Controls.Add($calendarExpirationDate)
$FormExpirationDate.Controls.Add($bExpirationDateCancel)
$FormExpirationDate.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$FormExpirationDate.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
$FormExpirationDate.Text = [System.String]'Expiration Date'
$FormExpirationDate.TopMost = $true
$FormExpirationDate.add_Load($FormExpirationDate_Load)
$FormExpirationDate.ResumeLayout($false)
Add-Member -InputObject $FormExpirationDate -Name calendarExpirationDate -Value $calendarExpirationDate -MemberType NoteProperty
Add-Member -InputObject $FormExpirationDate -Name lExpirationDate -Value $lExpirationDate -MemberType NoteProperty
Add-Member -InputObject $FormExpirationDate -Name bExpirationDateOK -Value $bExpirationDateOK -MemberType NoteProperty
Add-Member -InputObject $FormExpirationDate -Name bExpirationDateCancel -Value $bExpirationDateCancel -MemberType NoteProperty
Add-Member -InputObject $FormExpirationDate -Name cbExpirationDate -Value $cbExpirationDate -MemberType NoteProperty
}
. InitializeComponent
#endregion MonthCalendar Designer


#endregion Designers
$mainform.ShowDialog()
