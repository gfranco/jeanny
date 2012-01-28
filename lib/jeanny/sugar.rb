require 'singleton'
require 'yaml'

module Jeanny

    module Sugar

        # Singleton класс который взаимодействует c Jeanny
        class BridgeToJeanny

            include Singleton

            def initialize
                # refresh
            end

            def analyze(path, args = {})

                refresh

                begin

                    file_list = File.list path

                    fail JeannyFileNotFound, "файлы для анализа не найдены (Jeanny::Engine.analyze)" if file_list.empty?

                    file_meat = ''
                    file_list.each do |file|
                        file_meat = file_meat + File.open_file(file)
                    end

                    if @engine.analyze file_meat
                        @canbe[:save], @canbe[:process] = true, true
                        @canbe[:analyze] = false
                    end

                rescue StandardError => e
                    $stderr.puts "Ошибка: ".red + e.message
                    exit 1
                end

                @compare_file = (args[:compare_with] or '')

                # Завершаем метод если сравнивать ни с чем не надо
                return true if @compare_file.empty?

                # Если файл не найден, спрашиваем у юзернейма, как быть дальше,
                # продолжать без сравнения или прекратить работу.
                unless File.exists? @compare_file
                    puts "Файл с сохраненными классами не найден. Продолжаем без сравнения.".yellow
                    return true
                end

                saved_classes = []

                begin
                    saved_classes = YAML.load_file @compare_file
                    saved_classes.map! do |x|
                        x.to_a.flatten
                    end
                rescue Exception => e
                    $stderr.puts e.message
                    exit 1
                end

                # Сравниваем
                new_classes = @engine.compare_with saved_classes

                unless new_classes.nil? or new_classes.empty?
                    puts 'Новые классы: '
                    new_classes.each do |class_name|
                        puts "  #{class_name.ljust(40, '.')}#{@engine.classes[class_name].green}"
                    end
                end

                true

            end

            def save file = ''

                fail RuntimeError, 'на данном этапе нельзя вызывать сохранение классов' unless @canbe[:save]

                file = file.empty? ? @compare_file : file

                open(file, 'w') do |f|
                    f.puts @engine.classes.to_yaml
                end unless file.nil? or file.empty?

            end

            def save_to file
                save file
            end

            def group type, args = {}, &block

                begin

                    fail "We can`t process here..." unless @canbe[:process]
                    fail "Блоки process не должны быть рекурсивными" if @process_block_start
                    fail "Не передан блок" unless block_given?

                    @canbe[:process] = false
                    @canbe[:replace] = true

                    @process_block_start = true
                    @process_block = []

                    yield block

                    @process_block_start = false

                    @canbe[:replace] = false
                    @canbe[:process] = true

                rescue Exception => e
                    $stderr.puts "Ошибка: ".red + e.message
                    exit 1
                end

                @process_block.each do |replace|
                    File.list replace[:in] do |file, status|

                        # next unless status.zero?
                        unless status.zero?
                            puts file.red
                            next
                        end

                        exclude = false
                        replace[:ex].each do |exclude_rule|
                            if exclude_rule.kind_of? Regexp
                                exclude = file =~ exclude_rule
                            else
                                exclude = file.include? exclude_rule
                            end
                            break if exclude
                        end

                        if exclude
                            puts file.yellow
                            next
                        end

                        begin

                            puts file.green

                            data = File.open_file file
                            data = @engine.replace data, type

                            File.save_file file, data, replace[:prefix]

                        rescue Exception => e
                            puts e.message + "\n#{$@}"
                            exit 1
                        end

                    end
                end

            end

            def replace args = { }

                fail "We can`t replace here..." unless @canbe[:replace]

                struct = { :in => [], :ex => [], :prefix => '' }

                struct[:in] = ([args[:in]] | [args[:include]]).flatten.delete_if { |item| item.nil? or item.empty? }
                struct[:ex] = ([args[:ex]] | [args[:exclude]]).flatten.delete_if { |item| item.nil? or item.empty? }

                struct[:prefix] = args[:prefix] unless args[:prefix].nil?

                @process_block << struct if struct[:in].length > 0

            end

            private

            attr_reader :analyze_file, :compare_file
            attr_reader :engine
            attr_reader :canbe

            attr_reader :process_block_start
            attr_reader :process_block

            def refresh

                @engine = Engine.new
                @file_list, @compare_file = '', ''
                @canbe = { :analyze => true, :save => false, :process => false, :replace => false, :stat => false, :make => false }

                @process_block_start = false
                @process_block = []

            end

            def answer question, yes, no

                action, answers = '', [yes, no].flatten
                until answers.include? action
                    print "#{question} "
                    action = gets.chomp!
                end

                [yes].flatten.include? action

            end

        end

        # Тут перехватываем все несуществующие методы.
        # И те которые используются в DSL отправляем куда надо.
        def method_missing(method, *args, &block)
            BridgeToJeanny.instance.send(method, *args, &block) if BridgeToJeanny.instance.respond_to?(method)
        end

    end

end
