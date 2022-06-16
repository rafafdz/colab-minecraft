# Server JSON format

* `name`: Server identifier. The associated tar should have the same name
* `ssh-port`: The ssh port you will use to connect to the colab instance. This port is from the forwarding machine, but because the colab instance is using reverse SSH, it maps back to the colab server.
* `ssh-switch-port`: A temporary port used during the switching / renewal process. Choose anything you like
* `minecraft-port`: The port where minecraft is running in the colab server. This port will be mapped to 25565 in the forward server.
* `cookie-file`: The name of the cookie file used for automating the colab instance request. Will be looked for inside the directory cookies. This allows multiple accounts to be used.
* `next-reset-hour`: Used by the software to keep track of the time that the server needs renewal. Set any hour and it will be updated automatically.