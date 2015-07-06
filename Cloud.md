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
* look for a public AMI e.g. Centos 7.0
* Accept license agreement on Market Place URL, e.g. http://aws.amazon.com/marketplace/pp?sku=aw0evgkw8e5c1q413zgy5pjce
* now you can launch in AWS using vagrant

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

Packer needs this in the json file:

* `<builder>.source_ami`          - AMI ID for the image you want to use
* `<builder>.region`              - region where the instance will num
* `<builder>.instance_type`       - instance type, e.g. t2.micro
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
# packer build --only=aws workshop.json
```

NB: Look for the AMI ID at the end of the `packer build` output.
```
...
==> aws: Creating the AMI: workshop 1436193851
    aws: AMI: ami-c791d5fd
==> aws: Waiting for AMI to become ready...
...
Build 'aws' finished.

==> Builds finished. The artifacts of successful builds are:
--> aws: AMIs were created:

ap-southeast-2: ami-c791d5fd

```

# Vagrant
Vagrant needs this in the Vagrant file

* `aws.ami`                       - AMI ID for the image you want to use, see the output of the `packer build...`
* `aws.region`                    - region where the instance will run
* `aws.instance_type`             - instance type, e.g. t2.micro
* `aws.security_groups`           - security group(s), you need one with SSH allowed, "workshop"
* `override.ssh`.username         - user that Vagrant/Packer will use to connect to the insteance
* `aws.keypair_name`              - key pair name (SSH public key in AWS that is added to users), "workshop.key"
* `override.ssh.private_key_path` - private key (SSH private key matching the public key in AWS)

* Don't forget to set the aws.ami in your Vagrantfile.*

For AWS instances, you only need to use a 'dummy box'. The box created by Packer (packer-aws-virtualbox.box) does contain information about the image and region however Vagrant does not use it, even if you use that box. Mitchell Hashimoto provides a dummy box in the source repository for his vagrant-aws plugin.

Your box configuration looks like this:
```
    aws.vm.box               = "dummy"
    aws.vm.box_url           = "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box"
```

## To launch and use your instance:

**NB: Check if you have a packer-desktop-virtualbox.box file in the current directory. Delete it or Vagrant will upload this file (~400MB) to AWS. `config.vm.sync_folder.rsync__exclude` is currently broken**

```
# vagrant up aws
# vagrant ssh aws
```

## To delete your instance
```
# vagrant destroy aws
```

# Rebuilding your image
If you rebuild your image using Packer, you need to update the `aws.ami` in your Vagrantfile.
```
aws.ami = "yournewami"
```

When you next `vagrant up aws`, Vagrant will use your new image.

**NB: you need to clean up the AMI in AWS yourself.**