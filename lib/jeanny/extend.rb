class Module

    # Проверка наличия метода
    def jeanny_extension(method)
        if method_defined?(method)
            $stderr.puts "WARNING: Possible conflict with jeanny extension: #{self}##{method} already exists"
        else
            yield
        end
    end

end

class File

    jeanny_extension('open_file') do
        # Метод для чтения файла
        def self.open_file file
            # Если файл существует
            if exists?(expand_path(file))
                # Открываем, читаем, объединяем, возвращаем содержимое
                # open(expand_path(file), 'r').readlines.join
                open(expand_path(file), 'r').read
            else
                # Возвращаем пустую строку
                raise Jeanny::JeannyFileNotFound, "Файл не найден: #{expand_path(file)}"
            end
        end
    end

    jeanny_extension('open_file') do
        # Метод для сохранения файла
        def self.save_file file, data, prefix = ''
            # Если префикс не пустой, добавляем его к имени файла
            file = "#{dirname(expand_path(file))}/#{prefix}#{basename(file)}" unless prefix.nil? or prefix.empty?
            # Открываем файл
            open(file, 'w') do |file|
                # Помещаем данные
                file.puts data
            end
        end
    end

    jeanny_extension('list') do
        def self.list path

            file_list = []
            file_path = [path].flatten.map do |item|
                expand_path item
            end

            file_path.each do |file|

                list_item = Dir[file]
                file_list << list_item

                if block_given?
                    unless list_item.empty?
                        list_item.each { |x| yield x, 0 }
                    else
                        yield file, 1
                    end
                end

            end

            file_list.flatten

        end
    end

end

class String

    jeanny_extension('colorize') do
        # Функция для подсвечивания строки с помошью ANSI кодов...
        def colorize(color_code)
            unless PLATFORM =~ /win32/
                "#{color_code}#{self}\e[0m"
            else
                self
            end
        end
    end

    jeanny_extension('red') do
        # ... красным
        def red; colorize("\e[31m"); end
    end

    jeanny_extension('green') do
        # ... зеленым цветом
        def green; colorize("\e[32m"); end
    end

    jeanny_extension('yellow') do
        # ... и желтым
        def yellow; colorize("\e[33m"); end
    end

    jeanny_extension('each_expression') do
        def each_expression &block

            expression_list = []
            code, index, length = self.dup, 0, self.length

            while code[index, length].include? 'expression(' do
                brake = 0
                start = code[index, length].index 'expression('
                block = code[index + start, length]

                block.length.times do |i|
                    char = block[i, 1]
                    if char =~ /\(|\)/
                        brake = brake + 1 if char.eql? '('
                        brake = brake - 1 if char.eql? ')'

                        if brake.zero?
                            brake = block[0, i + 1]
                            break
                        end
                    end
                end

                index = index + start + brake.length
                expression_list << brake

                yield brake if block_given?

            end

            expression_list

        end
    end

    jeanny_extension 'replace_expressions' do
        def replace_expressions replace_string = '', &block
            code = self.dup
            self.each_expression do |expression|
                if block_given?
                    edoc = yield expression
                    code.gsub!(expression, edoc)
                else
                    code.gsub!(expression, replace_string)
                end
            end

            code
        end
    end

    jeanny_extension 'replace_expressions!' do
        def replace_expressions! replace_string = '', &block
            replace replace_expressions(replace_string, &block)
        end
    end

    jeanny_extension 'remove_expressions' do
        def remove_expressions
            replace_expressions ''
        end
    end

    jeanny_extension 'remove_expressions!' do
        def remove_expressions!
            replace replace_expressions ''
        end
    end

end

module Jeanny

    %w(FileNotFound CompareFileFormatError ClassesNotFound).each { |error| eval "class Jeanny#{error} < RuntimeError; end" }

end
