# Roadmap 2023 and future investigations

Azure Cloud Shell is an interactive, authenticated, browser-accessible shell for managing Azure
resources. As a web-based environment, Cloud Shell provides immediate management access to any
device with a network connection and provides a consistent and secure environment with
always-up-to-date tools. Users can work with their resources from any device, interactively, or
through automation

## FY2023 roadmap

The Azure Cloud Shell team plans to release the following features and updates in the Sept-Oct 2023
timeframe.

- Increase active user satisfaction and adoption with improvement’s to UX
- Decrease customer issues and increase adoption of VNET scenarios
- Reduce resource consumption and improve security without persistent storage with Ephemeral
  sessions
- Continued fraud reduction and enforcement
- Continue ACI migrations to further improve customer experience and availability

### Tenets

These are the Azure Cloud Shell guiding principles we use to evaluate and prioritize Cloud Shell
work activities:

- Cloud-based: Azure Cloud Shell is a cloud-based environment that provides users with access to a
  range of tools and resources, including bash, PowerShell, Azure CLI, and Azure PowerShell.
- Secure: Azure Cloud Shell is designed with security in mind, and provides a secure, isolated
  environment for users to work in.
- Accessible: Azure Cloud Shell is accessible from any device with an internet connection, making it
  easy for users to manage their resources from anywhere.
- Reliable: Azure Cloud Shell is reliable, with built-in redundancy and automatic failover.
- Efficient: Azure Cloud Shell is designed to be efficient, with always-up-to-date tools.
- Cost-effective: Azure Cloud Shell is cost-effective, with no additional charges for the service
  beyond the cost of the underlying Azure resources used by the user. It also helps to reduce costs
  by allowing users to automate tasks and work more efficiently.

Based on our tenets, these are the investment priorities for 2023.

### Improved User Interface

The user interface refresh will help improve the customer experience, accessibility, and
functionality of Cloud Shell. This will make it easier for users to navigate and find the tools and
resources they need. Benefits include:

- Improved user interface to be more modern and intuitive.
- Update color contrast and font sizes to improve accessibility for user that may have vision impairments.
- Support for enhanced functionality

### Ephemeral Sessions

Ephemeral sessions allow users to manage Azure resources faster without the overhead of creating and
associating Azure storage accounts. These temporary and disposable sessions are best for scenarios
where customers need to perform ad-hoc tasks without the need to persist data or files between
sessions. In addition, this provides a layer of security to scenarios to ensure that data or files
created during the session are not accessible to other users or processes after the session ends.

Benefits include:

- Allow customers to leverage Cloud Shell without a linked storage account
- Any saved files will be deleted with the container session
- Can be leveraged by partners to ensure that a customer can obtain a Cloud Shell session even if a
  storage account has never been configured
- Benefits command injection scenarios

### Improving VNET Configuration

Azure Cloud shell can be deployed to a local network (VNET) to gain access to local resources such
as virtual machines, databases, and other connected services. As popularity of VNET has increased,
so has a number of issues relating to configuration confusion and the need to improve both the
documentation and configuration of VNET scenarios.

The VNET refresh will address these issues by making improvements:

- Updating documentation to better guide customers through the process of enabling a VNET.
- Improving the configuration options of the VNET scenario.
- Providing guided assistance to customers through ready-made ARM templates.

## FY2024 Investments, Investigations and discussions

We are working with customers to investigate and discuss areas of improvement and new features.
We welcome your feedback. Please add issues or discussions to our repository.

- Multiple saved storage accounts
- Multiple/Custom images
- Improved editor experience
- Tenent/Subscription Administrative controls to manage Cloud Shell access.
- Toolbar tabs
- Improvements to Cloud Shell timeout values

We look forward to hearing from you!  Please join us in [Discussions](https://github.com/Azure/CloudShell/discussions).
