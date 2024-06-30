require 'sinatra'

get '/ler_arquivo_catalogo' do
  filename = params[:filename]
  filter_peso = params[:peso].to_f unless params[:peso].nil? || params[:peso].empty?
  filter_atividade = params[:atividade] unless params[:atividade].nil? || params[:atividade].empty?
  filter_sub_grupo = params[:subGrupo] unless params[:subGrupo].nil? || params[:subGrupo].empty?
  filter_complexidade = params[:complexidade] ? COMPLEXITY_MAPPING[params[:complexidade].to_i] : nil

  def remove_accents(str)
    str.tr(
      'áàãâäéèêëíìîïóòõôöúùûüçÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇ',
      'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'
    )
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
      sheet = xlsx.sheet(0)

      # Extrair cabeçalhos
      headers = sheet.row(1)

      # Preparar dados para retorno
      data = []

      # Iterar sobre todas as linhas (começando da segunda linha, pois a primeira é o cabeçalho)
      (2..sheet.last_row).each do |row_num|
        row_data = {}

        headers.each_with_index do |header, index|
          value = sheet.cell(row_num, index + 1)
          row_data[header] = value if value && !value.to_s.strip.empty?
        end

        # Aplicar filtros se especificados
        if (filter_peso.nil? || row_data['Peso'] == filter_peso && filter_peso != nil) &&
           (filter_complexidade.nil? || row_data['Complexidade'] == filter_complexidade) &&
           (filter_atividade.nil? || remove_accents(row_data['Atividade']).downcase.include?(remove_accents(filter_atividade).downcase)) &&
           (filter_sub_grupo.nil? || remove_accents(row_data['SubGrupo']).downcase.include?(remove_accents(filter_sub_grupo).downcase))
          data << row_data if row_data.any? # Adiciona apenas se houver dados na linha
        end
      end

      # Renderizar a tabela HTML
      erb :atividades,layout: :'layouts/layout', locals: { headers: headers, data: data }
    else
      status 404
      body "Arquivo #{filename} não encontrado!"
    end
  end
end
