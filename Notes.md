Packer + Vagrant Workshop - Additional Notes
============================================

# sudo, users and ttys

The CentOS base AMI used for the Cloud demonstration does not allow root logon. You logon as the user 'centos'

```
{
  ...
  "builders": [
    ...
    {
      "name":          "aws",
      "type":          "amazon-ebs",
      "ssh_username":  "centos",
      ...
```

To run the vagrant.sh requires root access because it creates the vagrant user and modifies the /etc/sudoers, therefore the packer provisioner for the vagrant.sh script includes a sudo execute_command specification.


```
{
  ...
  "provisioners": [
    ...
    {
      "type":            "shell",
      "execute_command": "{{ .Vars }} sudo -E -S sh '{{ .Path }}'",
      "scripts": [
        "scripts/vagrant.sh"
      ]
    },
      ...
```

As the same provisioner is used for both the Cloud and Desktop configurations, the packer build for Desktop will also run the vagrant.sh via sudo.

On the Desktop instance, sudo in requires a tty because the standard /etc/sudoers file created by the OS installer contains this:

```
Defaults requiretty
```

and our packer build fails like this when running the vagrant.sh script:

```
==> desktop: Provisioning with shell script: scripts/vagrant.sh
    desktop: sudo: sorry, you must have a tty to run sudo
```

To accommodate this requirement, you can tell packer to use a pty for its ssh connection.

```
{
  ...
  "builders": [
    ...
    {
      "name": "desktop",
      "type": "virtualbox-iso",
      ...
      "ssh_pty":          true,
      ...
```

To permanently disable the tty requirement, you can sed the /etc/sudoers file, which what is done by the vagrant.sh script. It is 'safe' to remove the requiretty - see https://bugzilla.redhat.com/show_bug.cgi?id=1020147#c7

## Other implementation options
Instead of using ssh_pty, the problem could be addresses in any number of ways.

### modify vagrant.sh
Modify the vagrant.sh script so that the sudo is included in the vagrant.sh script itself, e.g.

```
...
sudo sed -i -e '/Defaults.*requiretty/s/^/#/' /etc/sudoers
...
```

This can obscure the fact that you need sudo to perform the action. It also does not demonstrate the execute_command capabiliity of packer

### use sudo only for the Cloud image
As only the Cloud image requires sudo, you can create 2 separate provisioners and configure the Desktop provisioner to run without sudo (the Desktop image is accessed with root):

```
{
  ...
  "provisioners": [
    ...
    {
      "only":            [ "aws" ],
      "type":            "shell",
      "execute_command": "{{ .Vars }} sudo -E -S sh '{{ .Path }}'",
      "scripts": [
        "scripts/vagrant.sh"
      ]
    },

    {
      "only":            [ "desktop" ],
      "type":            "shell",
      "scripts": [
        "scripts/vagrant.sh"
      ]
    },
    ...
```

This can obscure the intent of this workshop.

### remove requiretty during kickstart

You can modify the /etc/sudoers file before packer provisioners takes control by adding this to the end of your kickstart file:

```
...
%post
sed -i -e '/Defaults.*requiretty/s/^/#/' /etc/sudoers
%end
```

This may obscure the configuration of the requiretty as it is outside the scope of the packer provisioners.

# Using the CentOS base AMI with vagrant only

The CentOS base AMI can be used directly with vagrant without needing to first create an AMI with packer. You can write a Vagrantfile that creates an instance using the CentOS base AMI. Any and all the operations performed by packer during the creation of the custom AMI can be performed by vagrant instead while provisioning the instance from the base AMI.

Vagrant uses sudo commands to accomplish a number of tasks on the AWS instance, such as any 'shell' provisioner which is 'privileged'

```
...
config.vm.provision "shell",
  privileged: true,
...
```

The 'synced_folder' provisioner also uses sudo.

```
...
config.vm.synced_folder ".", "/vagrant", type: "rsync",
  rsync__exclude: [".git/","packer_cache/", "builds/"] 
...
```

When vagrant tries to rsync the folder without sudo tty you will see this error

```
==> centos: Rsyncing folder: .../yourworkingdir/ => /vagrant
==> centos:   - Exclude: [".vagrant/", ".git/", "packer_cache/", "builds/"]
There was an error when attempting to rsync a synced folder.
Please inspect the error message below for more info.

Host path: .../yourworkingdir/
Guest path: /vagrant
Command: rsync --verbose --archive --delete -z --copy-links ... --rsync-path sudo rsync -e ssh -p 22 ...
...
sudo: sorry, you must have a tty to run sudo
rsync: connection unexpectedly closed (0 bytes received so far) [sender]
rsync error: error in rsync protocol data stream (code 12) at io.c(226) [sender=3.1.1]
```

Disabling the tty requirement on the instance must be done before vagrant provisioners interact with the instance. This can be done via cloud-init using the instance user-data.

To set instance user-data , use the 'user_data' attribute of vagrant's 'aws' provider (note the spelling of the attribute)

```
...
    centos.vm.provider :aws do |aws, override|
      aws.user_data = File.read('userdata.yml')
...
```

This is the equivalent of the packer instance user_data_file

```
{

  "builders": [
    {
      "name":          "aws",
      "type":          "amazon-ebs",
      "user_data_file": "userdata.yml",
      ...
```

You can try it out using the bonus-round Vagrantfile

```
# VAGRANT_VAGRANTFILE=bonus-round vagrant up centos
# VAGRANT_VAGRANTFILE=bonus-round vagrant ssh centos
```

Note that the username used for this configuration is 'centos' (see the centos.ssh.username). The bonus-round Vagrantfile does not create a 'vagrant' user. There is an inherent conflict between the user required to configure the box and the username you want to use when you run 'vagrant ssh'. You could create the 'vagrant' user and then use 'vagrant ssh ... -l vagrant' - left as an exercise for the reader.

# vagrant box file for AWS
Packer can create a box file ("`post-processor ... type : vagrant`") for the amazon-* builder which contains the AMI and region for the AMI. It should be possible for packer to create the box file using its vagrant post-processor and for vagrant with vagrant-aws to use that box file

e.g. in workshop.json do this:
```
  "post-processors": [
    {
      "output": "builds/packer_{{.BuildName}}_{{.Provider}}.box",
      "type":   "vagrant"
    }
  ]
```

and in Vagranfile do this:
```
...
  config.vm.define :aws do |aws|

    aws.vm.box               = "workshop-aws"
    aws.vm.box_url           = "builds/packer_aws_aws.box"
...
```

However, as as at packer 0.9.0 and vagrant-aws 0.7.0, vagrant does not properly use the AMI and region definitions in the box file. When the box does not exist vagrant does not first add the box and then use it (as happens with desktop virtualization). Instead vagrant fails like this:

```
There are errors in the configuration of this machine. Please fix
the following errors and try again:

AWS Provider:
* An AMI must be configured via "ami" (region: #{region})
```

This is because the `packer_aws_aws.box` Vagrantfile contains information associating the ami with the region like this

```
...
config.vm.provider "aws" do |aws|
    
  aws.region_config "ap-southeast-2", ami: "ami-f5fedf96"
  
end
...
```

Therefore you either have to manually add the box file after the `packer build...` using `vagrant box add...`

```
# vagrant box add --name workshop-aws builds/packer_aws_aws.box
```

while selecting only the region in your Vagrantfile

```
...
    config.vm.provider :aws do |aws, override|
      aws.region            = "ap-southeast-2"
...
```

OR you can use a dummy box while specifying the region and ami in your Vagrantfile


```
...
    config.vm.box     = "dummy"
    config.vm.box_url = "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box"
    config.vm.provider :aws do |aws, override|
      aws.region   = "ap-southeast-2"
      aws.ami      = "ami-f5fedf96"
...
```