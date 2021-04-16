# yandostreet

## v5

### Setup oh-my-zsh

#### Install whispir v5 api plugin
```zsh
pushd $ZSH/custom/plugins && \
  git clone git@github.com:johnlayton/yandostreet.git v5 && \
  popd || echo "I'm broken"
```
```zsh
plugins=(... v5)
```

### Setup other

```zsh
pushd $HOME && \
  git clone git@github.com:johnlayton/yandostreet.git .v5 && \
  popd || echo "I'm broken"
```

```zsh
source ~/.v5/v5.plugin.zsh
```

### Usage

#### 

```zsh
> v5 init | jq . -r
```

```zsh
> v5 workspace list
```
[Workspace List](./images/7ktY8hLycX/asciinema-recording.gif)

```zsh
> v5 workspace select 
```

```zsh
> v5 workspace show 
```
