# Jeanny

Библиотека для сокращения имён css классов.

## Пример использования

    #!/usr/bin/env ruby

    require 'rubygems'
    require 'jeanny'

    include Jeanny::Sugar

    analyze('serp/css/_*.css', :compare_with => 'classes.saved') and save

    group :html, :title => 'replacing in template files' do
        replace :in => 'serp/static/*.html'
    end

    group :css, :title => 'replacing in stylesheets' do
        replace :include => ['serp/css/_*.css', 'serp/block/*/*.css']
    end

    group :js, :title => 'replacing in scripts' do
        replace :in => 'serp/js/_serp.js'
    end

## Ещё один пример
    #!/usr/bin/env ruby
 
    require 'rubygems'
    require 'jeanny'
  
    j = Jeanny::Engine.new
    j.analyze '.l-head { ... } .l-head__l, .l-head__r { ... } .z-colors { ololo } .z-colors__text { blah-blah-blah... }'
   
    data = '<div class = "l-head"><div class = "l-head__l">Left</div><div class = "l-head__r">Right</div></div><div class = "z-colors"><div class = "z-colors__text">Colors Wizard</div></div>'
    puts j.replace data, :html
    
    # На выходе будет:
    # => <div class="a"><div class="d">Left</div><div class="e">Right</div></div><div class="b"><div class="f">Colors Wizard</div></div>
    
## Установка
sudo gem sources -a http://gemcutter.org && sudo gem install jeanny
