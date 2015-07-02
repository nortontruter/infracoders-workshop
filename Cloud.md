Packer + Vagrant Workshop - Cloud Platform
==========================================

# Objective:

Demonstration of Packer and Vagrant on a cloud platform, specifically AWS

The VM flavour of choice is CentOS

See Readme.md for workshop prerequisites

*NB: never commit your private credentials to your source repository* 

# Setup

## CentOS @ AWS
* look for a public AMI e.g. Centos 7.0
* Accept license agreement on Market Place URL, e.g. http://aws.amazon.com/marketplace/pp?sku=aw0evgkw8e5c1q413zgy5pjce
* now you can launch in AWS using vagrant

## vagrant-aws plugin
You need the vagrant-aws plugin. Install it like this:
```
vagrant plugin install vagrant-aws
```

## Credentials

Both Packer and Vagrant support AWS credentials from environment variables
```
AWS_ACCESS_KEY
AWS_SECRET_KEY
```

Simplest solution:

* set credentials once in script (e.g. via ~/.bashrc or in a aws.creds) and source that script in your environment
* naturally used from Packer if it can't find builder 'access_key' parameter
* in Vagrant set these keys in the AWS provider object
```
config.vm.provider :aws do |aws, override|
  aws.access_key_id             = ENV['AWS_ACCESS_KEY']
  aws.secret_access_key         = ENV['AWS_SECRET_KEY']
  ...
done
```

## SSH keys
You need to manage your own key pair, i.e. create a key pair and download the private key file. 
Upload a public key to AWS

## Security groups
You need to manage your security. Create a security group called "workshop" that allows SSH from anywhere


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
    {
      "type":            "shell",
      "execute_command": "{{ .Vars }} sudo -E -S sh '{{ .Path }}'",
      ...
    }

or if your sudo needs a password

    {
      "type":            "shell",
      "execute_command": "echo '{{user `ssh_pass`}}' | {{ .Vars }} sudo -E -S sh '{{ .Path }}'",
      ...
    }

# Vagrant configuration
Vagrant needs this in the Vagrant file

* aws.ami                       - AMI ID for the image you want to use
* aws.region                    - region where the instance will run
* aws.instance_type             - instance type, e.g. t2.micro
* aws.security_groups           - security group(s), you need one with SSH allowed
* override.ssh.username         - user that Vagrant/Packer will use to connect to the insteance
* aws.keypair_name              - key pair name (SSH public key in AWS that is added to users)
* override.ssh.private_key_path - private key (SSH private key matching the public key in AWS)

! security group

upload public key or create and download private key
??? how

!!!!! vagrant-aws plugin

. aws.creds