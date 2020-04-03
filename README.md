# lsws1clk
[![Build Status](https://api.travis-ci.com/Code-Egg/lsws1clk.svg?branch=master)](https://github.com/Code-Egg/lsws1clk)
[<img src="https://img.shields.io/badge/Made%20with-BASH-orange.svg">](https://en.wikipedia.org/wiki/Bash_(Unix_shell)) 

Description
--------

lsws1clk is a one-click installation script for LiteSpeed Web Server. Using this script,
you can quickly and easily install:
1. LSWS + PHP + MariaDB + WordPress + LiteSpeed Cache + Object Cache
2. LSWS + PHP + MariaDB + Magento2 + LiteMage

The script come with trial license by default which has 15 days for free. After that, you may want to apply with your license. 
License start from $0. [Read More](https://www.litespeedtech.com/products/litespeed-web-server/lsws-pricing)

# How to use
---------

## Install Pre-Requisites
For CentOS/RHEL Based Systems
```bash
yum install git -y
```

For Debian/Ubuntu Based Systems
```bash
apt install git -y
```

## Install
``` bash
git clone https://github.com/Code-Egg/lsws1clk.git
```
### WordPress
``` bash
lsws1clk/lsws1clk.sh -W
```
### Magento
``` bash
lsws1clk/lsws1clk.sh -M
```
### Magento + Sample data
``` bash
lsws1clk/lsws1clk.sh -M -S
```

## Benchmark
* Test client: 
online tool - [load.io](https://loader.io/) with 5000 clients 

* Test Server:
[DigitalOcean](https://www.digitalocean.com/) $5 plan server

* Target:
WordPress v5.3 main page 

* Result:
5000 request per seconds without any error

![](/img/loader-2.png)

![](/img/loader-3.png)

# Problems/Suggestions/Feedback/Contribution
Please raise an issue on the repository, or send a PR for contributing.

