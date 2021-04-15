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
