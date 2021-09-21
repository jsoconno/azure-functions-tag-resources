# Overview

The purpose of this code is to manage the Function responsible for tagging resources based on an event captured by a core Event Grid Subscription.

# Setup

## Install Node.JS

To develop a function locally using VS code, you will need to install VS Code and Node.JS so you can run `npm` commands.  To do this on Mac OS, you can use the following command with Homebrew:
```
brew install node
```
Other options for download can be found in the [documentation](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm).

This will install the latest, but you may need to install a different version for Azure.  In this case, we want version 13.12.0 or earlier.  You can do this by running:
```
brew install node@14
brew unlink node
brew link --overwrite node@14
node --version
```

## Install Core Tools

You can then install Core Tools using the following command:
```
npm install -g azure-functions-core-tools@3 --unsafe-perm true
```
Other options for download can be found in the [documentation](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local?tabs=windows%2Ccsharp%2Cportal%2Cbash%2Ckeda#install-the-azure-functions-core-tools).

## Install Azure Functions Extension
The next step is to install the Azure Functions extension for Visual Studio Code.  This can be done through the UI directly or from the command line using:
```
code install-extension ms-azuretools.vscode-azurefunctions
```

If you get an error that looks something like `bash: code: command not found`, it probably means that VS Code is not in your PATH.  Make sure that VS Code is in your applications folder, open the command pallet in VS Code (`command`+`shift`+`p`), type in `shell command`, and select the option to *Install 'code' command in PATH*.

## Install PowerShell
If you want to develop with PowerShell, you will also need to install PowerShell on your Mac.
```
brew install powershell
```
You can confirm this worked by running `pwsh --version` to get the version of PowerShell you are running.

## Install DotNet SDK

For PowerShell functions, you will also need to ensure you have dotnet (.NET Core SDK) installed.
```
brew install dotnet-sdk
```
This will install the latest, but you will likely need 3.1.0 at this time.  You can download multiple version of homebrew using the commands below:
```
brew tap isen-ng/dotnet-sdk-versions
brew install --cask dotnet-sdk3-1-400
```
For all available sdk versions, you can see the docs on [GitHub](https://github.com/isen-ng/homebrew-dotnet-sdk-versions).

# Deploy A Function

## Create an Azure Functions project
Click the Create New Project… icon in the Azure: Functions panel.

You will be prompted to choose a directory for your app. Choose an empty directory.

You will then be prompted to select a language for your project. Choose .

## Create a function
Click the Create Function… icon in the Azure: Functions panel.

You will be prompted to choose a template for your function. We recommend HTTP trigger for getting started.

## Run your function project locally
Press `F5` to run your function app.

The runtime will output a URL for any HTTP functions, which can be copied and run in your browser's address bar.

To stop debugging, press `Shift` + `F5`.

If you need more details during execution, you can run the function from the PowerShell terminal using `func start --verbose`.

Read the docs for more information on [creating a PowerShell function in Azure user VS Code](https://docs.microsoft.com/en-us/azure/azure-functions/create-first-function-vs-code-powershell).

If you have issues while running the the function, you can always restart the current PowerShell session by selecting `command` + `shift` + `p` and typing *PowerShell: Restart Current Session*.

## Deploy your code to Azure
Click the Deploy to Function App… () icon in the Azure: Functions panel.

When prompted to select a function app, choose fun-use-core-dev.