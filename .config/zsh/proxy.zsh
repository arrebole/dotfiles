# Local sing-box proxy controls.
proxy_on() {
  if ! systemctl --user start sing-box-client.service; then
    print -u2 'Failed to start sing-box-client.service'
    return 1
  fi

  export http_proxy='http://127.0.0.1:10808'
  export https_proxy='http://127.0.0.1:10808'
  export all_proxy='socks5h://127.0.0.1:10808'
  export HTTP_PROXY="$http_proxy"
  export HTTPS_PROXY="$https_proxy"
  export ALL_PROXY="$all_proxy"
  export no_proxy='localhost,127.0.0.1,::1'
  export NO_PROXY="$no_proxy"

  print 'Proxy enabled: 127.0.0.1:10808'
}

proxy_off() {
  unset http_proxy https_proxy all_proxy
  unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
  unset no_proxy NO_PROXY

  if ! systemctl --user stop sing-box-client.service; then
    print -u2 'Proxy variables cleared, but sing-box-client.service failed to stop'
    return 1
  fi

  print 'Proxy disabled'
}

proxy_status() {
  if systemctl --user is-active --quiet sing-box-client.service; then
    print 'Service: active'
  else
    print 'Service: inactive'
  fi

  if [[ -n "${all_proxy:-}" ]]; then
    print "Shell proxy: ${all_proxy}"
  else
    print 'Shell proxy: disabled'
  fi
}
