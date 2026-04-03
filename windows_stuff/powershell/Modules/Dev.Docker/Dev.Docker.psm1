function RunDockerEnvironment {
	
	$Host.UI.RawUI.WindowTitle = "Dev IDE"
	$PemFilePath = "$HOME/cert.pem"
    $image = "andrijkoenig/dev-env:nightly"
	
	
	
    $containerCmd = if (Get-Command docker -ErrorAction SilentlyContinue) {
        "docker"
    } elseif (Get-Command podman -ErrorAction SilentlyContinue) {
        "podman"
    } else {
        Write-Error "Neither Docker nor Podman is installed."
        return
    }
	
	# Base Docker args
    $argsList = @(
        "run"
        "-it"
        "--rm"
        "-v", "$HOME/projects:/projects"
    )
	
	if ($PemFilePath) {
		if (-Not (Test-Path $PemFilePath)) {
			Write-Warning "Provided PEM file does not exist: $PemFilePath"
		} else {
			# Mount the PEM file into a known path inside the container
			$resolvedPemPath = Resolve-Path $PemFilePath
			$argsList += "-v"
			$argsList += "${resolvedPemPath}:/tmp/cert.pem"
		}		
	}	

     # Append image name
    $argsList += "${image}"

    # Run container
    & $containerCmd @argsList
}

Set-Alias rde RunDockerEnvironment

Export-ModuleMember -Function RunDockerEnvironment -Alias rde
