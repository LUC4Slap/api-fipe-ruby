require 'sinatra'


get '/ler_arquivo_pge' do
  filename = params[:filename]
  sheet_number = params[:planilha]&.to_i

  unless sheet_number
    sheet_number = 0
  end

  # Verifica se o parâmetro filename foi fornecido
  if filename.nil? || filename.empty?
    status 400
    body "Parâmetro 'filename' não especificado!"
  else
    filepath = "#{settings.upload_folder}/#{filename}"

    # Verifica se o arquivo existe
    if File.exist?(filepath)
      # Ler o arquivo .xlsx usando roo
      xlsx = Roo::Spreadsheet.open(filepath)
      sheet = xlsx.sheet(sheet_number)

      # Extrair cabeçalhos
      headers = sheet.row(1)

      # Preparar estrutura para contagem por anos e soma dos valores 0.0 e asteristicos
      years = headers.select { |header| header.is_a?(Integer) || (header.is_a?(String) && header.match?(/^\d{4}$/)) }
      counts_by_year = {}
      total_rows_minus_asterisks_zeros = {}

      # Inicializar hashes para contagem e total de linhas menos asteriscos e zeros
      years.each do |year|
        counts_by_year[year] = { asterisks: 0, zeros: 0 }
        total_rows_minus_asterisks_zeros[year] = sheet.last_row - 1  # Total de linhas menos o cabeçalho

        # Inicialmente subtrai a soma de asteriscos e zeros
        total_rows_minus_asterisks_zeros[year] -= counts_by_year[year][:asterisks]
        total_rows_minus_asterisks_zeros[year] -= counts_by_year[year][:zeros]
      end

      # Iterar sobre todas as linhas (começando da segunda linha, pois a primeira é o cabeçalho)
      (2..sheet.last_row).each do |row_num|
        headers.each_with_index do |header, index|
          value = sheet.cell(row_num, index + 1)
          next unless years.include?(header)

          # Atualizar contagem para o ano correspondente
          if value == "*****"
            counts_by_year[header][:asterisks] += 1
          elsif value.to_f == 0.0
            counts_by_year[header][:zeros] += 1
          end

          # Atualizar total de linhas menos asteriscos e zeros para o ano correspondente
          total_rows_minus_asterisks_zeros[header] -= 1 if value == "*****" || value.to_f == 0.0
        end
      end

      # Preparar dados finais no formato desejado
      data = []

      (2..sheet.last_row).each do |row_num|
        row_data = {}

        headers.each_with_index do |header, index|
          value = sheet.cell(row_num, index + 1)
          # Remove o prefixo 'm' dos anos se existir
          header = header.to_s.gsub(/^m/, '') if header.is_a?(String)
          row_data[header] = value if value && !value.to_s.strip.empty?
        end

        data << row_data if row_data.any? # Adiciona apenas se houver dados na linha
      end

      # Montar o resultado final para retorno
      result = {
        data: data,
        counts_by_year: counts_by_year.transform_values { |counts| counts.merge(total_rows_minus_asterisks_zeros: total_rows_minus_asterisks_zeros) }
      }

      content_type :json
      result.to_json
    else
      status 404
      body "Arquivo #{filename} não encontrado!"
    end
  end
end
