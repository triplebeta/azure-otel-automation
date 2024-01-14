# Sample of how to setup Azure Automation
This is based on this repo: [https://github.com/jordanbean-msft/automation-ado](https://github.com/jordanbean-msft/automation-ado) so credits where credits are due.

The deployment script creates a link between version control and the Automation setup in Azure.
For more details please check the Git repo above.

## Configuring the pipelines
The infra templates for in this part are more complex. They use parameters and centralize the variable values in a few files. They are stored in the env subdirectory and in the env directory one level up.
I did not spend time to refactor this since my goal is to show how Azure Automation can be used.

Perhaps this can also be automated using Terraform since this setup seems complete but also a bit complicated. I already removed the Staging and Prod stages to simplify the setup.