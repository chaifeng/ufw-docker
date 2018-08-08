To Fix The Docker and UFW Security Flaw Without Disabling Iptables
==================

- [English](#tldr)
- [中文](#太长不想读)

## TL;DR

Please take a look at [Solving UFW and Docker issues](#solving-ufw-and-docker-issues).

## Problem

UFW is a popular iptables front end on Ubuntu that makes it easy to manage firewall rules. But when Docker is installed, Docker bypass the UFW rules and the published ports can be accessed from outside.

The issue is:

1. UFW is enabled on a server that provides external services, and all incoming connections that are not allowed are blocked by default.
2. Run a Docker container on the server and use the `-p` option to publish ports for that container on all IP addresses. 
   For example: `docker run -d --name httpd -p 0.0.0.0:8080:80 httpd:alpine`, this command will run an httpd service and publish port 80 of the container to port 8080 of the server.
3. UFW will not block all external requests to visit port 8080. Even the command `ufw deny 8080` will not prevent external access to this port.
4. This problem is actually quite serious, which means that a port that was originally intended to provide services internally is exposed to the public network.

Searching for "ufw docker" on the web can find a lot of discussion:

- https://github.com/moby/moby/issues/4737
- https://forums.docker.com/t/running-multiple-docker-containers-with-ufw-and-iptables-false/8953
- https://www.techrepublic.com/article/how-to-fix-the-docker-and-ufw-security-flaw/
- https://blog.viktorpetersson.com/2014/11/03/the-dangers-of-ufw-docker.html
- https://askubuntu.com/questions/652556/uncomplicated-firewall-ufw-is-not-blocking-anything-when-using-docker
- https://chjdev.com/2016/06/08/docker-ufw/
- https://askubuntu.com/questions/652556/uncomplicated-firewall-ufw-is-not-blocking-anything-when-using-docker
- https://my.oschina.net/abcfy2/blog/539485
- https://www.v2ex.com/amp/t/466666
- https://blog.36web.rocks/2016/07/08/docker-behind-ufw.html
- ...

Almost all of these solutions are similar. It requires to disable docker's iptables function first, but this also means that we give up docker's network management function. This causes containers will not be able to access the external network. It is also mentioned in some articles that you can manually add some rules in the UFW configuration file, such as `-A POSTROUTING ! -o docker0 -s 172.17.0.0/16 -j MASQUERADE`. But this only allows containers that belong to network 172.17.0.0/16 can access outside. If we create a new docker network, we must manually add such similar iptables rules for the new network.

## Expected goal

The solutions that we can find on internet are very similar and not elegant, I hope a new solution can:

- Don't need to disable Docker's iptables and let Docker to manage it's network. 
  We don't need to manually maintain iptables rules for any new Docker networks, and avoid potential side effects after disabling iptables in Docker.
- The public network cannot access ports that published by Docker. Even if the port is published on all IP addresses using an option like `-p 8080:80`. Containers and internal networks can visit each other normally.
  Although it is possible to have Docker publish a container's port to the server's private IP address, the port will not be accessed on the public network. But, this server may have multiple private IP addresses, and these private IP addresses may also change.
- In a very convenient way to allow/deny public networks to access container ports without additional software and extra configurations. Just like using command `ufw allow 8080` to allow external access port 8080, then using command `ufw delete allow 8080` to deny public networks visit port 8080.

## How to do?

### Revoke the original modification

If you have modified your server according to the current solution that we find on the internet, please rollback these changes first, including:

- Enable Docker's iptables feature.
  Remove all changes like `--iptables=false` , including configuration file `/etc/docker/daemon.json`.
- UFW's default FORWARD rule changes back to the default DROP instead of ACCEPT.
- Remove the rules related to the Docker network in the UFW configuration file `/etc/ufw/after.rules`.
- If you have modified Docker configuration files, restart Docker first. We will modify the UFW configuration later and we can restart it then.

### Solving UFW and Docker issues

This solution needs to modify only one UFW configuration file, all Docker configurations and options remain the default.

Modify the UFW configuration file `/etc/ufw/after.rules` and add the following rules at the end of the file:

    # BEGIN UFW AND DOCKER
    *filter
    :ufw-user-forward - [0:0]
    :DOCKER-USER - [0:0]
    -A DOCKER-USER -j RETURN -s 10.0.0.0/8
    -A DOCKER-USER -j RETURN -s 172.16.0.0/12
    -A DOCKER-USER -j RETURN -s 192.168.0.0/16

    -A DOCKER-USER -j ufw-user-forward

    -A DOCKER-USER -j DROP -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 192.168.0.0/16
    -A DOCKER-USER -j DROP -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 10.0.0.0/8
    -A DOCKER-USER -j DROP -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 172.16.0.0/12
    -A DOCKER-USER -j DROP -p udp -m udp --dport 0:32767 -d 192.168.0.0/16
    -A DOCKER-USER -j DROP -p udp -m udp --dport 0:32767 -d 10.0.0.0/8
    -A DOCKER-USER -j DROP -p udp -m udp --dport 0:32767 -d 172.16.0.0/12

    -A DOCKER-USER -j RETURN
    COMMIT
    # END UFW AND DOCKER

Using command `sudo systemctl restart ufw** to restart UFW after changing the file. Now the public network can't access any published docker ports, the container and the private network can visit each other normally, and the containers can also access the external network from inside. **There may be some unknown reasons cause the UFW rules will not take effect after restart UFW, please reboot servers. **

If you want to allow public networks to access the services provided by the Docker container, for example, the service port of a container is `80`. Run the following command to allow the public networks to access this service:

    ufw route allow proto tcp from any to any port 80

This allows the public network to access all published ports whose internal port is 80.

Note: If we publish a port by using option `-p 8080:80`, we should use the internal port `80`, not the mapping port `8080`.

If there are multiple containers with a service port of 80, but we only want the external network to access a certain container. For example, if the private address of the container is 172.17.0.2, use the following command:

    ufw route allow proto tcp from any to 172.17.0.2 port 80

If the network protocol of a service is UDP, for example a DNS service, you can use the following command to allow the external network to access all published DNS services:

    ufw route allow proto udp from any to any port 53

Similarly, if only for a specific container, such as IP address 172.17.0.2:

    ufw route allow proto udp from any to 172.17.0.2 port 53

## How it works?

The following rules allow the private networks to be able to visit each other. Normally, private networks are more trusted than public networks.

    -A DOCKER-USER -j RETURN -s 10.0.0.0/8
    -A DOCKER-USER -j RETURN -s 172.16.0.0/12
    -A DOCKER-USER -j RETURN -s 192.168.0.0/16

The following rules allow UFW to manage whether the public networks are allowed to visit the services provided by the Docker container. So that we can manage all firewall rules in one place.

    -A DOCKER-USER -j ufw-user-forward

The following rules block connection requests initiated by all public networks, but allow internal networks to access external networks. For TCP protocol, it prevents from actively establishing a TCP connection from public networks. For UDP protocol, all accesses to ports which is less then 32767 are blocked. Why is this port? Since the UDP protocol is stateless, it is not possible to block the handshake signal that initiates the connection request as TCP does. For GNU/Linux we can find the local port range in the file `/proc/sys/net/ipv4/ip_local_port_range`. The default range is `32768 60999`. When accessing a UDP protocol service from a running container, the local port will be randomly selected one from the port range, and the server will return the data to this random port. Therefore, we can assume that the listening port of the UDP protocol inside all containers are less then 32768. This is the reason that we don't want public networks to access the UDP ports that less then 32768.

    -A DOCKER-USER -j DROP -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 192.168.0.0/16
    -A DOCKER-USER -j DROP -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 10.0.0.0/8
    -A DOCKER-USER -j DROP -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 172.16.0.0/12
    -A DOCKER-USER -j DROP -p udp -m udp --dport 0:32767 -d 192.168.0.0/16
    -A DOCKER-USER -j DROP -p udp -m udp --dport 0:32767 -d 10.0.0.0/8
    -A DOCKER-USER -j DROP -p udp -m udp --dport 0:32767 -d 172.16.0.0/12

    -A DOCKER-USER -j RETURN

## 太长不想读

请直接看[解决 UFW 和 Docker 的问题](#解决-ufw-和-docker-的问题)。

## 问题

UFW 是 Ubuntu 上很流行的一个 iptables 前端，可以非常方便的管理防火墙的规则。但是当安装了 Docker，UFW 无法管理 Docker 发布出来的端口了。

具体现象是：

1. 在一个对外提供服务的服务器上启用了 UFW，并且默认阻止所有未被允许的传入连接。
2. 运行了一个 Docker 容器，并且使用 `-p` 选项来把该容器的某个端口发布到服务器的所有 IP 地址上。比如：`docker run -d --name httpd -p 0.0.0.0:8080:80 httpd:alpine` 将会运行一个 httpd 服务，并且将容器的 `80` 端口发布到服务器的 `8080` 端口上。
3. UFW 将不会阻止所有对 `8080` 端口访问的请求，用命令 `ufw deny 8080` 也无法阻止外部访问这个端口。

这个问题其实挺严重的，这意味着本来只是为了在内部提供服务的一个端口被暴露在公共网络上。

在网络上搜索 "ufw docker" 可以发现很多的讨论：

- https://github.com/moby/moby/issues/4737
- https://forums.docker.com/t/running-multiple-docker-containers-with-ufw-and-iptables-false/8953
- https://www.techrepublic.com/article/how-to-fix-the-docker-and-ufw-security-flaw/
- https://blog.viktorpetersson.com/2014/11/03/the-dangers-of-ufw-docker.html
- https://askubuntu.com/questions/652556/uncomplicated-firewall-ufw-is-not-blocking-anything-when-using-docker
- https://chjdev.com/2016/06/08/docker-ufw/
- https://askubuntu.com/questions/652556/uncomplicated-firewall-ufw-is-not-blocking-anything-when-using-docker
- https://my.oschina.net/abcfy2/blog/539485
- https://www.v2ex.com/amp/t/466666
- https://blog.36web.rocks/2016/07/08/docker-behind-ufw.html
- ...

基本上可以找到的解决办法就是首先禁用 docker 的 iptables 功能，但这也意味着放弃了 docker 的网络管理功能，很典型的现象就是容器将无法访问外部网络。在有的文章中也提到了可以在 UFW 的配置文件中手工添加一条规则，比如 `-A POSTROUTING ! -o docker0 -s 172.17.0.0/16 -j MASQUERADE`。但这也只是允许了 `172.17.0.0/16` 这个网络。如果有了新增的网络，我们也必须手工再为新增的网络添加这样类似的 iptables 规则。

## 期望的目标

目前网络上的解决方案都非常类似，而且也不优雅，我希望一个新的解决方案可以：

1. 不要禁用 Docker 的 iptables，像往常一样由 Docker 来管理自己的网络。这样有任何新增的 Docker 网络时都无需手工维护 iptables 规则，也避免了在 Docker 中禁用 iptables 之后可能带来的副作用。
2. 公共网络不可以访问 Docker 发布出来的端口，即使是使用类似 `-p 0.0.0.0:8080:80` 的选项把端口发布在所有的 IP 地址上。容器之间、内部网络之间都可以正常互相访问，只有公共网络不可以访问。
   虽然可以让 Docker 把容器的某一个端口映射到服务器的私有 IP 地址上，这样公共网络上将不会访问到这个端口。但是这个服务器可能有多个私有 IP 地址，这些私有 IP 地址可能也会发生变化。
3. 可以很方便的允许公共网络直接访问某个容器的端口，而无需额外的软件和配置。就像是用 `ufw allow 8080` 这样允许外部访问 8080 端口，然后用 `ufw delete allow 8080` 就不再允许外部访问。

## 如何做？

### 撤销原先的修改

如果已经按照目前网络上搜索到解决方案修改过了，请先修改回来，包括：

1. 启用 Docker 的 iptables 功能，删除所有类似 `--iptables=false` 的修改，包括 `/etc/docker/daemon.json` 配置文件。
2. UFW 的默认 `FORWARD` 规则改回默认的 `DROP`，而非 `ACCEPT`。
3. 删除 UFW 配置文件 `/etc/ufw/after.rules` 中与 Docker 网络相关的规则。
4. 如果修改了 Docker 相关的配置文件，重启 Docker。稍后还要修改 UFW 的配置，可以一并重启。

### 解决 UFW 和 Docker 的问题

目前新的解决方案只需要修改一个 UFW 配置文件即可，Docker 的所有配置和选项都保持默认。

修改 UFW 的配置文件 `/etc/ufw/after.rules`，在最后添加上如下规则：

    # BEGIN UFW AND DOCKER
    *filter
    :ufw-user-forward - [0:0]
    :DOCKER-USER - [0:0]
    -A DOCKER-USER -j RETURN -s 10.0.0.0/8
    -A DOCKER-USER -j RETURN -s 172.16.0.0/12
    -A DOCKER-USER -j RETURN -s 192.168.0.0/16

    -A DOCKER-USER -j ufw-user-forward

    -A DOCKER-USER -j DROP -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 192.168.0.0/16
    -A DOCKER-USER -j DROP -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 10.0.0.0/8
    -A DOCKER-USER -j DROP -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 172.16.0.0/12
    -A DOCKER-USER -j DROP -p udp -m udp --dport 0:32767 -d 192.168.0.0/16
    -A DOCKER-USER -j DROP -p udp -m udp --dport 0:32767 -d 10.0.0.0/8
    -A DOCKER-USER -j DROP -p udp -m udp --dport 0:32767 -d 172.16.0.0/12

    -A DOCKER-USER -j RETURN
    COMMIT
    # END UFW AND DOCKER
 
然后重启 UFW，`sudo systemctl restart ufw`。现在外部就已经无法访问 Docker 发布出来的任何端口了，但是容器内部以及私有网络地址上可以正常互相访问，而且容器也可以正常访问外部的网络。**可能由于某些未知原因，重启 UFW 之后规则也无法生效，请重启服务器。**

如果希望允许外部网络访问 Docker 容器提供的服务，比如有一个容器的服务端口是 `80`。那就可以用以下命令来允许外部网络访问这个服务：

    ufw route allow proto tcp from any to any port 80

这个命令会允许外部网络访问所有用 Docker 发布出来的并且内部服务端口为 `80` 的所有服务。

请注意，这个端口 `80` 是容器的端口，而非使用 `-p 0.0.0.0:8080:80` 选项发布在服务器上的 `8080` 端口。

如果有多个容器的服务端口为 80，但只希望外部网络访问某个特定的容器。比如该容器的私有地址为 `172.17.0.2`，就用类似下面的命令：

    ufw route allow proto tcp from any to 172.17.0.2 port 80

如果一个容器的服务是 UDP 协议，假如是 DNS 服务，可以用下面的命令来允许外部网络访问所有发布出来的 DNS 服务：

    ufw route allow proto udp from any to any port 53

同样的，如果只针对一个特定的容器，比如 IP 地址为 172.17.0.2：

    ufw route allow proto udp from any to 172.17.0.2 port 53

### 解释

在新增的这段规则中，下面这段规则是为了让私有网络地址可以互相访问。通常情况下，私有网络是比公共网络更信任的。

    -A DOCKER-USER -j RETURN -s 10.0.0.0/8
    -A DOCKER-USER -j RETURN -s 172.16.0.0/12
    -A DOCKER-USER -j RETURN -s 192.168.0.0/16

下面的规则是为了可以用 UFW 来管理外部网络是否允许访问 Docker 容器提供的服务，这样我们就可以在一个地方来管理防火墙的规则了。

    -A DOCKER-USER -j ufw-user-forward

下面的规则阻止了所有外部网络发起的连接请求，但是允许内部网络访问外部网络。对于 TCP 协议，是阻止了从外部网络主动建立 TCP 连接。对于 UDP，是阻止了所有小余端口 32767 的访问。为什么是这个端口的？由于 UDP 协议是无状态的，无法像 TCP 那样阻止发起建立连接请求的握手信号。在 GNU/Linux 上查看文件 `/proc/sys/net/ipv4/ip_local_port_range` 可以看到发出 TCP/UDP 数据后，本地源端口的范围，默认为 `32768 60999`。当从一个运行的容器对外访问一个 UDP 协议的服务时，本地端口将会从这个端口范围里面随机选择一个，服务器将会把数据返回到这个随机端口上。所以，我们可以假定所有容器内部的 UDP 协议的监听端口都小余 32768，不允许外部网络主动连接小余 32768 的 UDP 端口。

    -A DOCKER-USER -j DROP -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 192.168.0.0/16
    -A DOCKER-USER -j DROP -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 10.0.0.0/8
    -A DOCKER-USER -j DROP -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 172.16.0.0/12
    -A DOCKER-USER -j DROP -p udp -m udp --dport 0:32767 -d 192.168.0.0/16
    -A DOCKER-USER -j DROP -p udp -m udp --dport 0:32767 -d 10.0.0.0/8
    -A DOCKER-USER -j DROP -p udp -m udp --dport 0:32767 -d 172.16.0.0/12

    -A DOCKER-USER -j RETURN
