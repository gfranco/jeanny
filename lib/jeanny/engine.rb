
module Jeanny
    
    require 'strscan'

    # Класс который выполнят всю основную работу. 
    # Парсит и заменяет классы, сохраняет и сравнивает их.    
    class Engine

        attr_reader :classes

        def initialize
            @classes = Dictionary.new
        end

        # Метод ищет имена классов, в переданном ему тексте
        def analyze file_meat
            
            fail TypeError, "передан неверный аргумент (Jeanny::Engine.analyze)" if file_meat.empty?

            # Удаляем все экспрешены и удаляем все что в простых и фигурных скобках
            file_meat = file_meat.remove_expressions.gsub(/\{.*?\}/m , '{}').gsub(/\(.*?\)/, '()')

            short_words = generate_short_words

            # Находим имена классов
            file_meat.gsub(/\.([^\.,\{\} :#\[\]\*\n\s\/]+)/) do |match|
                # Если найденная строка соответствует маске и класс еще не был добавлен — добавляем его
                @classes[$1] = short_words.shift if match =~ /^\.([a-z]-.+)$/ and not(@classes.include? $1 ) 
            end

            fail JeannyClassesNotFound, "похоже, что в анализируемом файле нет классов подходящих по условию" if @classes.empty?
            
            # @classes.sort!
            @classes

        end
        
        # Метод сравниваеи найденные классы с переданными в аргументе saved_classes
        # и возвращает имена элементво которых нет в saved_classes
        def compare_with saved_classes

            return if saved_classes.nil? or saved_classes.empty?
            
            saved_classes = Dictionary.new saved_classes
            
            # находим новые классы
            new_classes = ((saved_classes.keys | @classes.keys) - saved_classes.keys)

            @classes = saved_classes

            # генерируем короткие имена и удаляем из них уже используемые
            short_words = generate_short_words - saved_classes.values
            new_classes.each do |class_name|
                @classes[class_name] = short_words.shift
            end
            
            # @classes.sort!

            new_classes

        end
        
        # Метод для замены классов
        def replace data, type
            
            fail "Тип блока не понятный" unless [:js, :css, :html, :tt2, :plain].include? type
            fail "nil Ololo" if data.nil?
            
            code = case type
                when :js then JSCode
                when :css then CSSCode
                when :tt2 then TT2Template
                when :html then HTMLCode
                when :plain then PlainCode
            end
            
            @classes.sort!
            
            code.new(data).replace @classes
            
        end

        private

        # Метод генерирует и возращает массив коротких имен.
        # По умолчанию генерируется 38471 имя. Если надо больше, добавить — легко        
        # UPD: Уже меньше, так как классы которые начинаются на "ad" не используются
        def generate_short_words again = false

            short_words = []

            %w(a aa a0 a_ a- aaa a00 a0a aa0 aa_ a_a aa- a-a a0_ a0- a_0 a-0).each do |name|
                max = name.length + 1
                while name.length < max
                    short_words << name unless name =~ /^ad/ or %w(el ek).include? name
                    name = name.next
                end
            end

            short_words

        end

    end

    # Класс-попытка реализовать что нибудь похожее на упорядоченный хэш
    class Dictionary

        include Enumerable

        attr_reader :keys, :values

        def initialize hash = {  }
            
            @keys = [ ]
            @values = [ ]

            hash.each_pair { |key, val| append key, val } if hash.kind_of? Hash
            hash.each { |item| append item[0], item[1]  } if hash.kind_of? Array

        end

        def [](key)
            if include? key
                @values[@keys.index(key)]
            else
                nil
            end
        end

        def []=(key, value)
            if include? key
                @values[@keys.index(key)] = value
            else
                append key, value
            end
        end

        def append key, value
            @keys << key
            @values << value
        end

        def include? class_name
            @keys.include? class_name
        end

        alias :has_key? include?

        def empty?
            @keys.empty?
        end

        def each
            @keys.length.times do |i|
                yield @keys[i], @values[i]
            end
        end
        
        def sort!
            @keys.map { |x| [x, @values[@keys.index(x)]] }.sort_by { |x| x[0].length }.reverse.each_with_index do |x, i|
                @keys[i] = x[0]
                @values[i] = x[1]
            end
        end

        def select_keys_if &block
            array = []
            @keys.length.times do |i|
                need_append = yield @keys[i], @values[i]
                array << @keys[i] if need_append
            end
            array
        end

        def length
            @keys.length
        end

        def last
            unless @keys.empty?
                [@keys.last, @values.last]
            end
        end

        def to_s
            each do |key, val|
                puts key.ljust(40) + val
            end
        end
        
        def to_a
            @keys.map { |x| [x, @values[@keys.index(x)]] }
        end

        def to_yaml
            yaml = []
            each do |key, val|
                yaml.push({ key => val })
            end
            yaml.to_yaml
        end

    end
    
    class Code
        
        attr_reader :code
        
        def initialize code
            @code = code
        end
        
        def replace classes
            
        end
        
    end
    
    class JSCode < Code
        
        def replace classes

            strings = Array.new
            each_string do |string|
                after = string.dup
                classes.each do |full_class, short_class|
                    while pos = after =~ /([^#]|^)#{full_class}(?=[^a-z0-9\-_\.\/]|$)/i
                       if $1.nil? or $1.empty?
                            after[pos, full_class.length] = short_class
                        else
                            after[pos + 1, full_class.length] = short_class
                        end
                    end
                end
                
                @code[@code.index(string), string.length] = after unless string.eql? after

            end
            
            @code
            
        end
        
        def each_string
            
            @status = :in_code

            @char, @last_char, @start_char, @value = '', '', '', ''
            
            scanner = StringScanner.new @code.dup

            until scanner.eos?

                scanner.getch or next
                @char = scanner.matched

                case @status


                    when :in_code
                        # Если мы в коде, а текущий символ один из тех что нам надо
                        # значит запоминаем, этот символ и переходим в режим "в строке"
                        if %w(" ').include? @char
                            @start_char = @char
                            @status = :in_string
                        end

                        # Если мы в коде, текущий символ слеш, а следующий не звездочка,
                        # значит мы в регулярном выражении
                        if @char.eql? '/' and @last_char =~ /=|\(|:/ and not %w(* /).include? scanner.post_match[0, 1]
                            @start_char = @char
                            @status = :in_regexp
                        end

                        # Если мы в коде, текущий символ звездочка, а предыдущий — слеш,
                        # значит это начала комментария. Перехоим в режим "в комментарии"
                        @status = :in_full_comment if @char.eql? '*' and @last_char.eql? '/'

                        @status = :in_line_comment if @char.eql? '/' and @last_char.eql? '/'

                    when :in_string, :in_regexp
                        # Если мы в строке (или регулярке), текущий символ такой же как и начальный,
                        # а предыдущий не экранирует его, значит строка законченна.
                        # Переходим в режим "в коде"
                        if @char.eql? @start_char and not @last_char.eql? '\\'
                            if block_given?
                                yield "#{@start_char}#{@value}#{@start_char}"
                            end

                            @status, @start_char, @value = :in_code, '', ''
                        # Иначе, прибавляем текущий символ к уже полученной строке
                        else
                            @value = @value + @char
                        end

                    when :in_full_comment
                        # Если мы в комментарии, текущий символ слеш, а предыдущий
                        # звездочка, значит комментарий закончился, переходим в режим "в коде"
                        @status = :in_code if @char.eql? '/' and @last_char.eql? '*'

                    when :in_line_comment
                        @status = :in_code if @char.eql? "\n"

                end

                @last_char = @char unless @char.nil? or @char =~ /\s/

            end
        end
        
        private 

        attr_accessor :status, :char, :last_char, :start_char, :value
        
    end
    
    class CSSCode < Code
        
        def replace classes
            
            # Заменяем в экспрешенах
            @code.each_expression do |expression|
                @code.gsub! expression do |a|
                    JSCode.new(expression).replace(classes)
                end
            end
            
            @code.gsub!(/\[class\^=(.*?)\]/) do |class_name|
                if classes.include? $1
                    class_name.gsub $1, classes[$1]
                else
                    class_name
                end
            end
            
            # Случайная строка
            unique_string = Time.now.object_id.to_s

            # Проходимся по классам
            classes.each do |full_name, short_name|
                
                # Заменяем старое имя класса на новое, плюс случайное число,
                # чтобы знать что этот класс мы уже изменяли
                #   TODO: Может это нахрен не надо?
                @code = @code.gsub(/\.#{full_name}(?=[^-\w])/, ".#{unique_string}#{short_name}")
            end

            # После замены имен классов, случайное число уже не нужно,
            # так что удаляем его, и возвращаем css с замененными значениями
            @code.gsub(unique_string, '')
            
        end
        
    end
    
    class HTMLCode < Code
        
        def replace classes
            
            # Заменяем классы во встроенных стилях
            @code.gsub!(/<style[^>]*?>(.*?)<\s*\/\s*style\s*>/mi) do |style|
                style.gsub($1, CSSCode.new($1).replace(classes))
            end

            # Заменяем классы во встроенных скриптах
            @code.gsub!(/<script[^>]*?>(.*?)<\s*\/\s*script\s*>/mi) do |script|
                script.gsub($1, JSCode.new($1).replace(classes))
            end
            
            # Находим аттрибуты с именем "class"
            # TODO: Надо находить не просто "class=blablabl", а искать
            #       именно теги с аттрибутом "class"
            @code.gsub!(/class\s*=\s*('|")(.*?)\1/) do |match|
            
                # берем то что в кавычках и разбиваем по пробелам
                match = $2.split(' ')
                quote = $1
                
                # проходимся по получившемуся массиву
                match.map! do |class_name|
                    
                    # удаляем проблелы по бокам
                    class_name = class_name.strip
                    
                    # и если в нашем списке замены есть такой класс заменяем на новое значение
                    if classes.has_key? class_name
                        classes[class_name]
                    else
                        class_name
                    end
                    # elsif class_name.eql? 'g-js'
                    #     class_name
                    # end
                    
                end.delete_if { |class_name| class_name.nil? or class_name.empty? }
                
                unless match.empty?
                    "class=#{quote}#{match.join(' ')}#{quote}"
                else
                    ''
                end
                
            end
            
            # Находим тэги с аттрибутами в которых может быть js
            @code.gsub!(/<[^>]*?(onload|onunload|onclick|ondblclick|onmousedown|onmouseup|onmouseover|onmousemove|onmouseout|onfocus|onblur|onkeypress|onkeydown|onkeyup|onsubmit|onreset|onselect|onchange)\s*=\s*("|')((\\\2|.)*?)\2[^>]*?>/mi) do |tag|
                tag.gsub($3, JSCode.new($3.gsub(/\\-/ , '-')).replace(classes))
            end
            
            @code
            
        end
        
    end
    
    class TT2Template < HTMLCode
        
        def replace classes

            tags = Array.new
            mark = self.object_id

            @code.gsub! /\[%(.*?)%\]/m do |tag|
                tags.push tag and "#{mark}:#{tags.length - 1}:"
            end

            super classes

            classes.each do |full_class, short_class|
                tags.map! do |tag|
                    tag.gsub /((BLOCK|PROCESS|INCLUDE|INSERT)\s+('|").*?[^\\]\3)|(('|").*?[^\\]\5)/ do |string|
                        unless $5.nil?
                            string.gsub /#{full_class}(?=[\s"']|$|\\["'])/, short_class
                        else
                            string
                        end
                    end
                end
            end

            tags.select.with_index do |tag, index|
                @code.gsub! "#{mark}:#{index}:", tag
            end

            @code
            
        end
        
    end
    
    class PlainCode < Code
        
    end

end
