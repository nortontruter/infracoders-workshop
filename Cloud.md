Packer + Vagrant Workshop - Cloud Platform
==========================================

# Objective:

Demonstration of Packer and Vagrant on a cloud platform, specifically AWS

The VM flavour of choice is CentOS

See [Readme.md](Readme.md) for workshop prerequisites

*NB: never commit your private credentials to your source repository* 

# Setup

## Credentials
Both Packer and Vagrant support AWS credentials from environment variables
```
AWS_ACCESS_KEY
AWS_SECRET_KEY
```

Simplest solution:

* set credentials once in script (e.g. via ~/.bashrc or in ./aws.creds) and source that script in your environment
* naturally used from Packer if it can't find builder 'access_key' parameter
* in Vagrant set these keys in the AWS provider object
```
config.vm.provider :aws do |aws, override|
  aws.access_key_id             = ENV['AWS_ACCESS_KEY']
  aws.secret_access_key         = ENV['AWS_SECRET_KEY']
  ...
done
```

## CentOS @ AWS
This workshop builds packer from a CentOS 7 AMI. You need to accept the license conditions for the AMI
* look for a public AMI e.g. CentOS 7
* Accept license agreement on Market Place URL, e.g. http://aws.amazon.com/marketplace/pp?sku=aw0evgkw8e5c1q413zgy5pjce
* now you can launch in AWS

## vagrant-aws plugin
You need the vagrant-aws plugin. Install it like this:
```
# vagrant plugin install vagrant-aws
```

## SSH keys
Vagrant requires an ssh keys pair for access to your VM. The public key need to be uploaded to AWS.

Create an ssh key
```
# ssh-keygen -t rsa -f workshop.key -N "" -C workshop.key
```

Upload the workshop.key.pub to your AWS account and call it "workshop.key"


## Security groups
For Vagrant, you need to manage your security. Create a security group called "workshop" that allows SSH from anywhere.


# Packer
Packer creates (and deletes) its own:

* keypair                       - key pair name for SSH access to the host
* security_group                - security group to allow adequate access to the instance

This workshop builds packer a CentOS 7 AMI. Packer needs this in the workshop.json:

Packer needs this in the json file:

* `<builder>.source_ami`          - AMI ID for the image you want to use
* `<builder>.region`              - region where the instance will run
* `<builder>.instance_type`       - instance type, e.g. m3.medium
* `<builder>.ssh_username`        - user that Packer will use to connect to the instance

Cloud images typically don't allow root logon. Access is via a well-known user using your own keypair (the one Packer creates for you)

To run commands with sudo using Packer you need this:
```
{
  "type":            "shell",
  "execute_command": "{{ .Vars }} sudo -E -S sh '{{ .Path }}'",
  ...
}
```

or if your sudo needs a password
```
{
  "type":            "shell",
  "execute_command": "echo '{{user `ssh_pass`}}' | {{ .Vars }} sudo -E -S sh '{{ .Path }}'",
  ...
}
```

## To build your Packer image:

```
# . aws.creds
# packer build --only=cloud workshop.json
```

NB: Look for the AMI ID at the end of the `packer build` output.
```
...
==> cloud: Creating the AMI: workshop 1436193851
    cloud: AMI: ami-c791d5fd
==> cloud: Waiting for AMI to become ready...
...
Build 'cloud' finished.

==> Builds finished. The artifacts of successful builds are:
--> cloud: AMIs were created:

ap-southeast-2: ami-c791d5fd

```

# Vagrant
Vagrant needs to know this

* `aws.ami`                     - ami-id naming the AMI you want to deploy
* `aws.region`                  - region where the instance will run
* `aws.instance_type`           - instance type - e.g. t2.micro
* `aws.security_groups`         - security group(s) - you need one with SSH allowed, you created one earlier called "workshop"
* `aws.keypair_name`            - key pair name (SSH public key in AWS that is added to users) - you uploaded one earlier called "workshop.key"
* `config.ssh.private_key_path` - private key (SSH private key matching the public key in AWS) - you created one earlier with ssh-keygen

The box created by Packer (builds/packer_cloud_aws.box) contains information associating the ami-id you created with the region, you need to select the region for the instance.

Your instance configuration looks like this:
```
  config.ssh.private_key_path = "workshop.key"
  ...
    cloud.vm.box               = "workshop-cloud"
    cloud.vm.provider :aws do |aws|
      aws.region            = "ap-southeast-2"
      aws.instance_type     = "t2.micro"
      aws.security_groups   = [ "workshop" ]
      aws.keypair_name      = "workshop.key"
```

Using this method also requires you to add the box first before you run vagrant.

To see your box catalog:
```
# vagrant box list
```

To manually add the box, you need to do this:
```
# vagrant box add --name workshop-cloud builds/packer_cloud_aws.box
```

## To launch and use your instance:

**NB: Check if you have a packer_desktop_virtualbox.box file in the current directory. Delete it or Vagrant will upload this file (~400MB) to AWS. `config.vm.sync_folder.rsync__exclude` is currently broken**

```
# vagrant up cloud
# vagrant ssh cloud
```

## To delete your instance
```
# vagrant destroy cloud
```

# Rebuilding your image
If you rebuild your image using Packer, you need to reload your box file
```
# vagrant box remove workshop-cloud
# vagrant box add --name workshop-cloud builds/packer_cloud_aws.box
```

When you next `vagrant up aws`, Vagrant will use your new image.

**NB: you need to clean up the AMI in AWS yourself.**