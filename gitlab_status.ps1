# Fixed GitLab Statistics Script - Counts actual lines from diff
param(
    [string]$GitLabUrl = "**********",  # Replace with your GitLab URL
    [string]$Token = "********",         # Replace with your token
    [string]$Username = "******",        # Replace with your username
    [int]$Year = 2025
)

# Set encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

Write-Host "==============================================="
Write-Host "    GitLab Complete Contribution Statistics"
Write-Host "==============================================="
Write-Host "Year: $Year"
Write-Host "User: $Username"
Write-Host "Start time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "==============================================="
Write-Host ""

# Set API headers
$headers = @{
    "PRIVATE-TOKEN" = $Token
}

# Store results
$results = @{
    TotalMergeRequests = 0
    TotalCommits = 0
    TotalFilesChanged = 0
    TotalLinesAdded = 0
    TotalLinesDeleted = 0
    MR_Details = @()
    Commit_Details = @()
    Project_Summary = @{}
}

# Cache for projects
$projectCache = @{}

# Function: Count lines in diff
function Count-DiffLines {
    param([string]$diff)
    
    $additions = 0
    $deletions = 0
    
    if ([string]::IsNullOrEmpty($diff)) {
        return @{Additions=0; Deletions=0}
    }
    
    $lines = $diff -split "`n"
    
    foreach ($line in $lines) {
        if ($line.StartsWith("+") -and -not $line.StartsWith("+++")) {
            $additions++
        }
        elseif ($line.StartsWith("-") -and -not $line.StartsWith("---")) {
            $deletions++
        }
    }
    
    return @{Additions=$additions; Deletions=$deletions}
}

# Function: Get paginated data
function Get-PaginatedData {
    param(
        [string]$Url,
        [int]$MaxItems = 1000
    )
    
    $allItems = @()
    $page = 1
    $itemsPerPage = 100
    $totalFetched = 0
    
    do {
        $pagedUrl = if ($Url -match '\?') { "$Url&page=$page&per_page=$itemsPerPage" } else { "$Url?page=$page&per_page=$itemsPerPage" }
        
        try {
            $response = Invoke-RestMethod -Uri $pagedUrl -Headers $headers
            
            if ($response -and $response.Count -gt 0) {
                $allItems += $response
                $totalFetched += $response.Count
                
                Write-Host "  Page ${page}: Found $($response.Count) items" -ForegroundColor Gray
            }
            
            $page++
            
            # Avoid rate limiting
            Start-Sleep -Milliseconds 200
            
            # Stop if reached max items
            if ($MaxItems -gt 0 -and $totalFetched -ge $MaxItems) {
                break
            }
            
        } catch {
            Write-Host "  Error fetching page ${page}: $($_.Exception.Message)" -ForegroundColor Yellow
            break
        }
        
    } while ($response -and $response.Count -eq $itemsPerPage)
    
    return $allItems
}

try {
    # 1. Get user info
    Write-Host "[1/6] Getting user information..." -ForegroundColor Cyan
    $userUrl = "$GitLabUrl/api/v4/users?username=$Username"
    $user = Invoke-RestMethod -Uri $userUrl -Headers $headers
    
    if (-not $user -or $user.Count -eq 0) {
        Write-Host "Error: User '$Username' not found" -ForegroundColor Red
        exit 1
    }
    
    $userId = $user[0].id
    $userName = $user[0].name
    $userEmail = $user[0].email
    Write-Host "User: $userName (ID: $userId)" -ForegroundColor Green
    Write-Host ""
    
    # 2. Get all projects the user is a member of
    Write-Host "[2/6] Getting project list..." -ForegroundColor Cyan
    $projectsUrl = "$GitLabUrl/api/v4/projects?membership=true&simple=true"
    $allProjects = Get-PaginatedData -Url $projectsUrl
    
    Write-Host "Total projects found: $($allProjects.Count)" -ForegroundColor Green
    Write-Host ""
    
    if ($allProjects.Count -eq 0) {
        Write-Host "Error: No projects found" -ForegroundColor Red
        exit 1
    }
    
    # Cache project info
    foreach ($project in $allProjects) {
        $projectCache[$project.id] = $project
    }
    
    # 3. Count Merge Requests
    Write-Host "[3/6] Counting Merge Requests..." -ForegroundColor Cyan
    $mrUrl = "$GitLabUrl/api/v4/merge_requests?author_id=$userId&state=merged&created_after=$Year-01-01&created_before=$($Year+1)-01-01&scope=all"
    $allMRs = Get-PaginatedData -Url $mrUrl
    
    $results.TotalMergeRequests = $allMRs.Count
    Write-Host "Found $($allMRs.Count) Merge Requests" -ForegroundColor Green
    
    if ($allMRs.Count -gt 0) {
        Write-Host "Analyzing each Merge Request..." -ForegroundColor Cyan
        
        for ($i = 0; $i -lt $allMRs.Count; $i++) {
            $mr = $allMRs[$i]
            
            # Show progress
            $percent = [math]::Round(($i + 1) / $allMRs.Count * 100, 1)
            Write-Progress -Activity "Analyzing Merge Requests" -Status "$percent% Complete" -PercentComplete $percent
            
            $mrId = $mr.iid
            $projectId = $mr.project_id
            
            try {
                # Get MR changes
                $mrChangesUrl = "$GitLabUrl/api/v4/projects/$projectId/merge_requests/$mrId/changes"
                $changes = Invoke-RestMethod -Uri $mrChangesUrl -Headers $headers
                
                $filesChanged = $changes.changes.Count
                $mrAdditions = 0
                $mrDeletions = 0
                
                # Get additions and deletions from API
                if ($changes.additions -gt 0 -or $changes.deletions -gt 0) {
                    $mrAdditions = $changes.additions
                    $mrDeletions = $changes.deletions
                } else {
                    # If API doesn't return line count, try to count from diff
                    foreach ($change in $changes.changes) {
                        $diffResult = Count-DiffLines -diff $change.diff
                        $mrAdditions += $diffResult.Additions
                        $mrDeletions += $diffResult.Deletions
                    }
                }
                
                $projectName = $projectCache[$projectId].name
                
                # Record MR details
                $mrDetail = [PSCustomObject]@{
                    Type = "Merge Request"
                    ID = $mr.iid
                    Title = $mr.title
                    Project = $projectName
                    Files = $filesChanged
                    Additions = $mrAdditions
                    Deletions = $mrDeletions
                    Created = $mr.created_at
                    State = $mr.state
                }
                
                $results.MR_Details += $mrDetail
                
                # Update totals
                $results.TotalFilesChanged += $filesChanged
                $results.TotalLinesAdded += $mrAdditions
                $results.TotalLinesDeleted += $mrDeletions
                
                # Summarize by project
                if (-not $results.Project_Summary.ContainsKey($projectName)) {
                    $results.Project_Summary[$projectName] = @{
                        MR_Count = 0
                        Commit_Count = 0
                        Total_Files = 0
                        Total_Additions = 0
                        Total_Deletions = 0
                    }
                }
                
                $results.Project_Summary[$projectName].MR_Count++
                $results.Project_Summary[$projectName].Total_Files += $filesChanged
                $results.Project_Summary[$projectName].Total_Additions += $mrAdditions
                $results.Project_Summary[$projectName].Total_Deletions += $mrDeletions
                
            } catch {
                Write-Host "  MR $mrId error: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            
            # Avoid API rate limiting
            Start-Sleep -Milliseconds 300
        }
        
        Write-Progress -Activity "Analyzing Merge Requests" -Completed
        Write-Host "Merge Request analysis completed" -ForegroundColor Green
    }
    
    Write-Host ""
    
    # 4. Count Commits
    Write-Host "[4/6] Counting Commits..." -ForegroundColor Cyan
    $totalCommits = 0
    
    # Count commits for each project
    for ($i = 0; $i -lt $allProjects.Count; $i++) {
        $project = $allProjects[$i]
        $projectId = $project.id
        $projectName = $project.name
        
        # Show progress
        $percent = [math]::Round(($i + 1) / $allProjects.Count * 100, 1)
        Write-Progress -Activity "Analyzing Commits" -Status "$percent% Complete" -PercentComplete $percent
        Write-Host "  Project: $projectName" -NoNewline
        
        try {
            # Get commits for this project
            $commitsUrl = "$GitLabUrl/api/v4/projects/$projectId/repository/commits?since=$Year-01-01&until=$Year-12-31&per_page=100"
            $commits = Get-PaginatedData -Url $commitsUrl -MaxItems 1000
            
            if ($commits.Count -gt 0) {
                # Filter user's commits
                $userCommits = $commits | Where-Object { 
                    $_.author_email -eq $userEmail -or 
                    $_.author_name -eq $userName -or
                    $_.committer_email -eq $userEmail -or
                    $_.committer_name -eq $userName
                }
                
                $projectCommits = $userCommits.Count
                $totalCommits += $projectCommits
                
                Write-Host " - Found $projectCommits commits" -ForegroundColor Green
                
                # Analyze each commit
                $analyzedCommits = 0
                foreach ($commit in $userCommits | Select-Object -First 20) { # Limit to first 20 commits
                    $commitId = $commit.id
                    
                    try {
                        $commitDetails = Invoke-RestMethod -Uri "$GitLabUrl/api/v4/projects/$projectId/repository/commits/$commitId" -Headers $headers
                        
                        if ($commitDetails.stats) {
                            $commitAdditions = $commitDetails.stats.additions
                            $commitDeletions = $commitDetails.stats.deletions
                            
                            # Record commit details
                            $commitDetail = [PSCustomObject]@{
                                Type = "Commit"
                                ID = $commit.id.Substring(0, 8)
                                Title = $commit.title
                                Project = $projectName
                                Files = 0
                                Additions = $commitAdditions
                                Deletions = $commitDeletions
                                Created = $commit.committed_date
                                State = "Committed"
                            }
                            
                            $results.Commit_Details += $commitDetail
                            
                            # Update project summary
                            if (-not $results.Project_Summary.ContainsKey($projectName)) {
                                $results.Project_Summary[$projectName] = @{
                                    MR_Count = 0
                                    Commit_Count = 0
                                    Total_Files = 0
                                    Total_Additions = 0
                                    Total_Deletions = 0
                                }
                            }
                            
                            $results.Project_Summary[$projectName].Commit_Count++
                            $results.Project_Summary[$projectName].Total_Additions += $commitAdditions
                            $results.Project_Summary[$projectName].Total_Deletions += $commitDeletions
                            
                            $analyzedCommits++
                        }
                        
                        Start-Sleep -Milliseconds 100
                        
                    } catch {
                        # Skip commit on error
                    }
                }
                
                if ($analyzedCommits -gt 0) {
                    $results.TotalLinesAdded += ($results.Project_Summary[$projectName].Total_Additions)
                    $results.TotalLinesDeleted += ($results.Project_Summary[$projectName].Total_Deletions)
                }
                
            } else {
                Write-Host " - No commits" -ForegroundColor Gray
            }
            
        } catch {
            Write-Host " - Error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Avoid API rate limiting
        Start-Sleep -Milliseconds 200
    }
    
    Write-Progress -Activity "Analyzing Commits" -Completed
    $results.TotalCommits = $totalCommits
    Write-Host "Total commits found: $totalCommits" -ForegroundColor Green
    Write-Host ""
    
    # 5. Summarize all data
    Write-Host "[5/6] Summarizing statistics..." -ForegroundColor Cyan
    
    # Recalculate totals to ensure accuracy
    $totalMRs = 0
    $totalCommits = 0
    $totalFiles = 0
    $totalAdditions = 0
    $totalDeletions = 0
    
    foreach ($projectName in $results.Project_Summary.Keys) {
        $stats = $results.Project_Summary[$projectName]
        $totalMRs += $stats.MR_Count
        $totalCommits += $stats.Commit_Count
        $totalFiles += $stats.Total_Files
        $totalAdditions += $stats.Total_Additions
        $totalDeletions += $stats.Total_Deletions
    }
    
    $results.TotalMergeRequests = $totalMRs
    $results.TotalCommits = $totalCommits
    $results.TotalFilesChanged = $totalFiles
    $results.TotalLinesAdded = $totalAdditions
    $results.TotalLinesDeleted = $totalDeletions
    
    # 6. Display final results
    Write-Host "[6/6] Generating report..." -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "==============================================="
    Write-Host "             FINAL STATISTICS"
    Write-Host "==============================================="
    Write-Host ""
    
    Write-Host "=== OVERALL STATISTICS ===" -ForegroundColor Green
    Write-Host "Year: $Year" -ForegroundColor Yellow
    Write-Host "User: $userName" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Merge Requests: $($results.TotalMergeRequests)" -ForegroundColor Cyan
    Write-Host "Commits: $($results.TotalCommits)" -ForegroundColor Cyan
    Write-Host "Files Changed: $($results.TotalFilesChanged)" -ForegroundColor Cyan
    Write-Host "Lines Added: $($results.TotalLinesAdded)" -ForegroundColor Cyan
    Write-Host "Lines Deleted: $($results.TotalLinesDeleted)" -ForegroundColor Cyan
    Write-Host "Net Lines Changed: $($results.TotalLinesAdded - $results.TotalLinesDeleted)" -ForegroundColor Cyan
    Write-Host ""
    
    # Show statistics by project
    if ($results.Project_Summary.Count -gt 0) {
        Write-Host "=== STATISTICS BY PROJECT ===" -ForegroundColor Green
        
        $projectSummaryList = @()
        foreach ($projectName in $results.Project_Summary.Keys) {
            $stats = $results.Project_Summary[$projectName]
            $netChange = $stats.Total_Additions - $stats.Total_Deletions
            
            $projectSummaryList += [PSCustomObject]@{
                Project_Name = $projectName
                MR_Count = $stats.MR_Count
                Commit_Count = $stats.Commit_Count
                Files_Changed = $stats.Total_Files
                Lines_Added = $stats.Total_Additions
                Lines_Deleted = $stats.Total_Deletions
                Net_Lines = $netChange
            }
        }
        
        $projectSummaryList | Sort-Object Net_Lines -Descending | Format-Table -AutoSize
        Write-Host ""
    }
    
    # Show Top 10 Merge Requests
    if ($results.MR_Details.Count -gt 0) {
        Write-Host "=== TOP 10 MERGE REQUESTS (by lines changed) ===" -ForegroundColor Green
        
        $topMRs = $results.MR_Details | Sort-Object { $_.Additions + $_.Deletions } -Descending | Select-Object -First 10
        
        for ($i = 0; $i -lt $topMRs.Count; $i++) {
            $mr = $topMRs[$i]
            $totalLines = $mr.Additions + $mr.Deletions
            $title = if ($mr.Title.Length -gt 50) { $mr.Title.Substring(0, 47) + "..." } else { $mr.Title }
            
            Write-Host "$($i+1). $title" -ForegroundColor Yellow
            Write-Host "   Project: $($mr.Project), Files: $($mr.Files), Changes: +$($mr.Additions)/-$($mr.Deletions) (Total: $totalLines lines)" -ForegroundColor Gray
        }
        
        Write-Host ""
    }
    
    # Show Top 10 Commits
    if ($results.Commit_Details.Count -gt 0) {
        Write-Host "=== TOP 10 COMMITS (by lines changed) ===" -ForegroundColor Green
        
        $topCommits = $results.Commit_Details | Sort-Object { $_.Additions + $_.Deletions } -Descending | Select-Object -First 10
        
        for ($i = 0; $i -lt $topCommits.Count; $i++) {
            $commit = $topCommits[$i]
            $totalLines = $commit.Additions + $commit.Deletions
            $title = if ($commit.Title.Length -gt 50) { $commit.Title.Substring(0, 47) + "..." } else { $commit.Title }
            
            Write-Host "$($i+1). $title" -ForegroundColor Yellow
            Write-Host "   Project: $($commit.Project), Changes: +$($commit.Additions)/-$($commit.Deletions) (Total: $totalLines lines)" -ForegroundColor Gray
        }
        
        Write-Host ""
    }
    
    # Export data to CSV
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $csvFile = "gitlab_stats_${Year}_${timestamp}.csv"
    
    $exportData = @()
    $exportData += $results.MR_Details
    $exportData += $results.Commit_Details
    
    if ($exportData.Count -gt 0) {
        $exportData | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
        Write-Host "Detailed data exported to: $csvFile" -ForegroundColor Green
        Write-Host ""
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}

Write-Host "==============================================="
Write-Host "End time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "==============================================="
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")