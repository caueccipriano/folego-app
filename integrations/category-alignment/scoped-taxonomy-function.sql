-- Already applied and verified on 2026-10-13. Preserves financial rows and other spaces.
CREATE OR REPLACE FUNCTION private.seed_universal_taxonomy(p_space_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  -- Moradia
  perform private.ensure_system_category(p_space_id,'expense','expense.housing','Moradia',null,array['Casa'],array[]::text[],false,true,'#2C8B55',10,array['moradia','casa'],false,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.housing.rent','Aluguel','expense.housing',array['Aluguel'],array['Moradia'],true,true,'#2C8B55',11,array['aluguel'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.housing.mortgage','Financiamento imobiliário','expense.housing',array[]::text[],array[]::text[],false,true,'#2C8B55',12,array['financiamento casa','imovel','hipoteca'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.housing.condo','Condomínio','expense.housing',array['Condomínio'],array['Moradia'],true,true,'#2C8B55',13,array['condominio'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.housing.property_tax','IPTU','expense.housing',array[]::text[],array[]::text[],false,true,'#2C8B55',14,array['iptu','imposto predial'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.housing.maintenance','Manutenção / reparos','expense.housing',array['Manutenção'],array['Moradia'],false,true,'#2C8B55',15,array['manutencao','reparo','reparos'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.housing.furniture','Móveis / decoração','expense.housing',array['Móveis / utilidades'],array['Moradia'],false,false,'#2C8B55',16,array['moveis','decoracao','utilidades'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.housing.domestic_services','Serviços domésticos','expense.housing',array[]::text[],array[]::text[],false,false,'#2C8B55',17,array['faxina','diarista','servicos domesticos'],true,'economic');

  -- Contas da casa
  perform private.ensure_system_category(p_space_id,'expense','expense.household','Contas da casa',null,array[]::text[],array[]::text[],false,true,'#B35A00',20,array['contas casa','utilidades'],false,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.household.water','Água','expense.household',array['Água'],array['Contas da casa'],true,true,'#B35A00',21,array['agua'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.household.energy','Energia','expense.household',array['Energia'],array['Contas da casa'],true,true,'#B35A00',22,array['energia','luz','eletricidade'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.household.gas','Gás','expense.household',array['Gás'],array['Contas da casa'],true,true,'#B35A00',23,array['gas'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.household.internet','Internet','expense.household',array['Internet / telefone','Internet/Telefone','Internet'],array['Contas da casa'],true,true,'#B35A00',24,array['internet','wifi','fibra'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.household.phone','Telefone','expense.household',array['Telefone'],array['Contas da casa'],true,true,'#B35A00',25,array['telefone','celular','plano movel'],true,'economic');

  -- Alimentação
  perform private.ensure_system_category(p_space_id,'expense','expense.food','Alimentação',null,array[]::text[],array[]::text[],false,true,'#6C3CE9',30,array['alimentacao','comida'],false,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.food.groceries','Supermercado','expense.food',array['Supermercado','Mercado'],array['Alimentação'],true,true,'#6C3CE9',31,array['supermercado','mercado','compras mercado'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.food.restaurant','Restaurantes','expense.food',array['Restaurante','Restaurantes'],array['Alimentação'],true,false,'#6C3CE9',32,array['restaurante','restaurantes','jantar','almoco'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.food.delivery','Delivery','expense.food',array['Delivery'],array['Alimentação'],true,false,'#6C3CE9',33,array['delivery','entrega comida','ifood'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.food.cafe','Café / lanche','expense.food',array['Café / Lanche','Café / lanche'],array['Alimentação'],true,false,'#6C3CE9',34,array['cafe','lanche','padaria'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.food.bars','Bares','expense.food',array[]::text[],array[]::text[],false,false,'#6C3CE9',35,array['bar','bares','drinks'],true,'economic');

  -- Transporte
  perform private.ensure_system_category(p_space_id,'expense','expense.transport','Transporte',null,array[]::text[],array[]::text[],false,true,'#5E7F14',40,array['transporte','carro','mobilidade'],false,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.transport.fuel','Combustível','expense.transport',array['Gasolina','Combustível'],array['Transporte'],true,true,'#5E7F14',41,array['gas','gasolina','combustivel','posto'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.transport.ride','Uber / Táxi','expense.transport',array['Uber / Táxi','Uber / Taxi'],array['Transporte'],true,false,'#5E7F14',42,array['uber','taxi','99','corrida'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.transport.public','Transporte público','expense.transport',array['Transporte público'],array['Transporte'],true,true,'#5E7F14',43,array['onibus','metro','trem','transporte publico'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.transport.parking_toll','Estacionamento / pedágio','expense.transport',array['Estacionamento / pedágio'],array['Transporte'],true,false,'#5E7F14',44,array['estacionamento','pedagio'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.transport.maintenance','Manutenção do veículo','expense.transport',array['Manutenção'],array['Transporte'],false,true,'#5E7F14',45,array['manutencao carro','oficina','revisao','pneu'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.transport.vehicle_tax','IPVA / Licenciamento','expense.transport',array[]::text[],array[]::text[],false,true,'#5E7F14',46,array['ipva','licenciamento','documento carro'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.transport.rental','Aluguel de veículo','expense.transport',array[]::text[],array[]::text[],false,false,'#5E7F14',47,array['aluguel carro','locacao veiculo'],true,'economic');

  -- Saúde & bem-estar
  perform private.ensure_system_category(p_space_id,'expense','expense.health','Saúde & bem-estar',null,array['Saúde'],array[]::text[],false,true,'#B93E66',50,array['saude','bem estar'],false,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.health.plan','Plano de saúde','expense.health',array[]::text[],array[]::text[],false,true,'#B93E66',51,array['plano saude','convenio'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.health.consultation','Consultas','expense.health',array['Consulta','Consultas'],array['Saúde','Saúde & bem-estar'],false,true,'#B93E66',52,array['consulta','medico'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.health.exams','Exames','expense.health',array['Exames'],array['Saúde','Saúde & bem-estar'],false,true,'#B93E66',53,array['exame','laboratorio'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.health.pharmacy','Farmácia','expense.health',array['Farmácia'],array['Saúde','Saúde & bem-estar'],true,true,'#B93E66',54,array['farm','farmacia','drogaria','remedio'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.health.dental','Odontologia','expense.health',array[]::text[],array[]::text[],false,true,'#B93E66',55,array['dentista','odontologia'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.health.therapy','Terapia','expense.health',array['Terapia'],array['Saúde','Saúde & bem-estar'],false,true,'#B93E66',56,array['terapia','psicologo'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.health.fitness','Academia / bem-estar','expense.health',array['Academia / bem-estar'],array['Saúde','Saúde & bem-estar'],false,false,'#B93E66',57,array['academia','fitness','bem estar'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.health.supplements','Suplementos','expense.health',array[]::text[],array[]::text[],false,false,'#B93E66',58,array['suplemento','vitamina'],true,'economic');

  -- Educação
  perform private.ensure_system_category(p_space_id,'expense','expense.education','Educação',null,array[]::text[],array[]::text[],false,true,'#4A57C8',60,array['educacao','estudo'],false,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.education.school','Escola / Faculdade','expense.education',array['Faculdade','Escola / Faculdade'],array['Educação'],true,true,'#4A57C8',61,array['escola','faculdade','mensalidade'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.education.courses','Cursos','expense.education',array['Cursos'],array['Educação'],false,false,'#4A57C8',62,array['curso','cursos'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.education.books','Livros / material','expense.education',array['Livros / material'],array['Educação'],false,false,'#4A57C8',63,array['livro','material escolar'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.education.languages','Idiomas','expense.education',array[]::text[],array[]::text[],false,false,'#4A57C8',64,array['idioma','ingles','espanhol','lingua'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.education.certifications','Certificações','expense.education',array[]::text[],array[]::text[],false,false,'#4A57C8',65,array['certificacao','prova','certificado'],true,'economic');

  -- Compras
  perform private.ensure_system_category(p_space_id,'expense','expense.shopping','Compras',null,array[]::text[],array[]::text[],false,false,'#9A6A00',70,array['compras','produtos'],false,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.shopping.clothes','Roupas','expense.shopping',array['Roupas'],array['Vestuário'],false,false,'#9A6A00',71,array['roupa','roupas','vestuario'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.shopping.shoes','Calçados','expense.shopping',array['Calçados'],array['Vestuário'],false,false,'#9A6A00',72,array['calcado','sapato','tenis'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.shopping.accessories','Acessórios','expense.shopping',array['Acessórios'],array['Vestuário'],false,false,'#9A6A00',73,array['acessorio','acessorios'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.shopping.electronics','Eletrônicos','expense.shopping',array['Eletrônicos'],array['Compras'],true,false,'#9A6A00',74,array['eletronico','celular','notebook'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.shopping.home','Casa / decoração','expense.shopping',array['Casa'],array['Compras'],false,false,'#9A6A00',75,array['casa','decoracao','utilidades'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.shopping.marketplace','Marketplace','expense.shopping',array['Marketplace'],array['Compras'],false,false,'#9A6A00',76,array['marketplace','market place'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.shopping.online','Compras online','expense.shopping',array['Compras online'],array['Compras'],true,false,'#9A6A00',77,array['online','ecommerce','e-commerce'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.shopping.other','Outros produtos','expense.shopping',array[]::text[],array[]::text[],false,false,'#9A6A00',78,array['outro produto','produto'],true,'economic');

  -- Assinaturas
  perform private.ensure_system_category(p_space_id,'expense','expense.subscriptions','Assinaturas',null,array['Assinaturas e serviços'],array[]::text[],false,false,'#1774B8',80,array['assinatura','servico digital'],false,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.subscriptions.streaming','Streaming','expense.subscriptions',array['Streaming'],array['Assinaturas','Assinaturas e serviços'],false,false,'#1774B8',81,array['streaming','video'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.subscriptions.music','Música','expense.subscriptions',array['Música'],array['Assinaturas','Assinaturas e serviços'],false,false,'#1774B8',82,array['musica','audio'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.subscriptions.apps','Apps','expense.subscriptions',array['Apps'],array['Assinaturas','Assinaturas e serviços'],false,false,'#1774B8',83,array['app','aplicativo'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.subscriptions.software','Software','expense.subscriptions',array['Software'],array['Assinaturas','Assinaturas e serviços'],false,false,'#1774B8',84,array['software','saas'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.subscriptions.cloud','Nuvem / armazenamento','expense.subscriptions',array[]::text[],array[]::text[],false,false,'#1774B8',85,array['nuvem','cloud','armazenamento'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.subscriptions.content','Notícias / conteúdo','expense.subscriptions',array[]::text[],array[]::text[],false,false,'#1774B8',86,array['noticia','conteudo','jornal','revista'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.subscriptions.other','Outros serviços digitais','expense.subscriptions',array[]::text[],array[]::text[],false,false,'#1774B8',87,array['servico digital','assinatura digital'],true,'economic');

  -- Lazer & entretenimento
  perform private.ensure_system_category(p_space_id,'expense','expense.leisure','Lazer & entretenimento',null,array['Lazer'],array[]::text[],false,false,'#8242B5',90,array['lazer','entretenimento'],false,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.leisure.cinema','Cinema','expense.leisure',array['Cinema'],array['Lazer','Lazer & entretenimento'],false,false,'#8242B5',91,array['cinema','filme'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.leisure.events','Eventos / shows','expense.leisure',array['Eventos'],array['Lazer','Lazer & entretenimento'],false,false,'#8242B5',92,array['evento','show','festival'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.leisure.games','Jogos','expense.leisure',array['Jogos'],array['Lazer','Lazer & entretenimento'],false,false,'#8242B5',93,array['jogo','games'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.leisure.hobbies','Hobbies','expense.leisure',array['Hobbies'],array['Lazer','Lazer & entretenimento'],false,false,'#8242B5',94,array['hobby','hobbies'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.leisure.outings','Passeios','expense.leisure',array['Passeios'],array['Lazer','Lazer & entretenimento'],false,false,'#8242B5',95,array['passeio','passeios'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.leisure.parties','Baladas / festas','expense.leisure',array[]::text[],array[]::text[],false,false,'#8242B5',96,array['balada','festa','boate'],true,'economic');

  -- Beleza & cuidados
  perform private.ensure_system_category(p_space_id,'expense','expense.beauty','Beleza & cuidados',null,array['Beleza e cuidados','Beleza','Cuidados pessoais'],array[]::text[],false,false,'#D4457A',100,array['beleza','cuidados'],false,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.beauty.hair','Cabelo / barbearia','expense.beauty',array['Cabelo / barbearia'],array['Beleza e cuidados','Beleza & cuidados','Beleza'],false,false,'#D4457A',101,array['cabelo','barbearia','salao'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.beauty.aesthetics','Estética','expense.beauty',array['Estética'],array['Beleza e cuidados','Beleza & cuidados','Beleza'],false,false,'#D4457A',102,array['estetica'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.beauty.cosmetics','Cosméticos','expense.beauty',array['Cosméticos'],array['Beleza e cuidados','Beleza & cuidados','Beleza'],false,false,'#D4457A',103,array['cosmetico','maquiagem'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.beauty.personal','Cuidados pessoais','expense.beauty',array['Cuidados pessoais'],array['Beleza e cuidados','Beleza & cuidados','Beleza'],false,false,'#D4457A',104,array['cuidados pessoais','higiene'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.beauty.laundry','Lavanderia','expense.beauty',array[]::text[],array[]::text[],false,false,'#D4457A',105,array['lavanderia','lavagem roupa'],true,'economic');

  -- Família & dependentes
  perform private.ensure_system_category(p_space_id,'expense','expense.family','Família & dependentes',null,array['Família e pets'],array[]::text[],false,true,'#16816D',110,array['familia','dependente'],false,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.family.children','Filhos','expense.family',array[]::text[],array[]::text[],false,true,'#16816D',111,array['filho','filhos'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.family.school','Escola / creche','expense.family',array[]::text[],array[]::text[],false,true,'#16816D',112,array['creche','escola filho'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.family.nanny','Babá','expense.family',array[]::text[],array[]::text[],false,true,'#16816D',113,array['baba'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.family.alimony','Pensão','expense.family',array[]::text[],array[]::text[],false,true,'#16816D',114,array['pensao'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.family.support','Apoio familiar','expense.family',array[]::text[],array[]::text[],false,true,'#16816D',115,array['apoio familiar','ajuda familia'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.family.elderly','Idosos / dependentes','expense.family',array[]::text[],array[]::text[],false,true,'#16816D',116,array['idoso','dependente'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.family.other','Outros','expense.family',array[]::text[],array[]::text[],false,false,'#16816D',117,array['outros familia'],true,'economic');

  -- Pets
  perform private.ensure_system_category(p_space_id,'expense','expense.pets','Pets',null,array[]::text[],array[]::text[],false,false,'#247B95',120,array['pet','pets','animal'],false,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.pets.food','Alimentação','expense.pets',array[]::text[],array[]::text[],false,false,'#247B95',121,array['racao','comida pet'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.pets.vet','Veterinário','expense.pets',array[]::text[],array[]::text[],false,false,'#247B95',122,array['veterinario','vet'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.pets.medicine','Medicamentos','expense.pets',array[]::text[],array[]::text[],false,false,'#247B95',123,array['medicamento pet','remedio pet'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.pets.grooming','Banho / tosa','expense.pets',array[]::text[],array[]::text[],false,false,'#247B95',124,array['banho pet','tosa'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.pets.accessories','Acessórios','expense.pets',array[]::text[],array[]::text[],false,false,'#247B95',125,array['acessorio pet'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.pets.other','Outros','expense.pets',array[]::text[],array[]::text[],false,false,'#247B95',126,array['outros pet'],true,'economic');

  -- Viagens
  perform private.ensure_system_category(p_space_id,'expense','expense.travel','Viagens',null,array[]::text[],array[]::text[],false,false,'#167D91',130,array['viagem','viagens','ferias'],false,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.travel.tickets','Passagens','expense.travel',array[]::text[],array[]::text[],false,false,'#167D91',131,array['passagem','voo','onibus viagem'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.travel.lodging','Hospedagem','expense.travel',array[]::text[],array[]::text[],false,false,'#167D91',132,array['hotel','hospedagem','pousada'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.travel.local_transport','Transporte local','expense.travel',array[]::text[],array[]::text[],false,false,'#167D91',133,array['transporte viagem','transporte local'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.travel.food','Alimentação em viagem','expense.travel',array[]::text[],array[]::text[],false,false,'#167D91',134,array['comida viagem','alimentacao viagem'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.travel.attractions','Passeios / atrações','expense.travel',array[]::text[],array[]::text[],false,false,'#167D91',135,array['atracao','passeio viagem','ingresso viagem'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.travel.insurance','Seguro viagem','expense.travel',array[]::text[],array[]::text[],false,false,'#167D91',136,array['seguro viagem'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.travel.fees','Taxas','expense.travel',array[]::text[],array[]::text[],false,false,'#167D91',137,array['taxa viagem'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.travel.other','Outros','expense.travel',array[]::text[],array[]::text[],false,false,'#167D91',138,array['outros viagem'],true,'economic');

  -- Presentes & doações
  perform private.ensure_system_category(p_space_id,'expense','expense.gifts','Presentes & doações',null,array['Presentes'],array[]::text[],false,false,'#B84F3B',140,array['presente','doacao'],false,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.gifts.presents','Presentes','expense.gifts',array[]::text[],array[]::text[],false,false,'#B84F3B',141,array['presente','presentes'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.gifts.celebrations','Datas comemorativas','expense.gifts',array['Datas comemorativas'],array['Presentes','Presentes & doações'],false,false,'#B84F3B',142,array['aniversario','natal','data comemorativa'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.gifts.donations','Doações','expense.gifts',array['Doações'],array['Presentes','Presentes & doações'],false,false,'#B84F3B',143,array['doacao','doacoes'],true,'economic');

  -- Seguros
  perform private.ensure_system_category(p_space_id,'expense','expense.insurance','Seguros',null,array[]::text[],array[]::text[],false,true,'#7054B8',150,array['seguro','seguros'],false,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.insurance.auto','Auto','expense.insurance',array[]::text[],array[]::text[],false,true,'#7054B8',151,array['seguro auto','seguro carro'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.insurance.home','Residencial','expense.insurance',array[]::text[],array[]::text[],false,true,'#7054B8',152,array['seguro residencial','seguro casa'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.insurance.life','Vida','expense.insurance',array[]::text[],array[]::text[],false,true,'#7054B8',153,array['seguro vida'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.insurance.health','Saúde','expense.insurance',array[]::text[],array[]::text[],false,true,'#7054B8',154,array['seguro saude'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.insurance.electronics','Celular / eletrônicos','expense.insurance',array[]::text[],array[]::text[],false,false,'#7054B8',155,array['seguro celular','seguro eletronico'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.insurance.travel','Viagem','expense.insurance',array[]::text[],array[]::text[],false,false,'#7054B8',156,array['seguro viagem'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.insurance.other','Outros','expense.insurance',array[]::text[],array[]::text[],false,false,'#7054B8',157,array['outros seguro'],true,'economic');

  -- Financeiro & impostos
  perform private.ensure_system_category(p_space_id,'expense','expense.finance','Financeiro & impostos',null,array['Financeiro'],array[]::text[],false,false,'#16816D',160,array['financeiro','imposto','taxa'],false,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.finance.bank_fees','Tarifas bancárias','expense.finance',array['Tarifas bancárias'],array['Financeiro','Financeiro & impostos'],true,false,'#16816D',161,array['tarifa','tarifa bancaria'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.finance.interest','Juros','expense.finance',array['Juros'],array['Financeiro','Financeiro & impostos'],false,false,'#16816D',162,array['juros'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.finance.taxes','Impostos','expense.finance',array[]::text[],array[]::text[],false,true,'#16816D',163,array['imposto','tributo'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.finance.iof_fees','IOF / taxas','expense.finance',array['IOF / taxas'],array['Financeiro','Financeiro & impostos'],false,false,'#16816D',164,array['iof','taxas financeiras'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.finance.fines','Multas','expense.finance',array[]::text[],array[]::text[],false,false,'#16816D',165,array['multa'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.finance.accounting','Contabilidade','expense.finance',array[]::text[],array[]::text[],false,false,'#16816D',166,array['contador','contabilidade'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.finance.other','Outras despesas financeiras','expense.finance',array['Ajustes financeiros'],array['Financeiro','Financeiro & impostos'],false,false,'#16816D',167,array['despesa financeira','ajuste financeiro'],true,'economic');

  -- Dívidas & financiamentos
  perform private.ensure_system_category(p_space_id,'expense','expense.debt','Dívidas & financiamentos',null,array['Dívidas e empréstimos'],array[]::text[],false,true,'#B33A3A',170,array['divida','financiamento','emprestimo'],false,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.debt.loans','Empréstimos','expense.debt',array['Empréstimos'],array['Dívidas e empréstimos','Dívidas & financiamentos'],true,true,'#B33A3A',171,array['emprestimo'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.debt.financing','Financiamentos','expense.debt',array['Financiamentos'],array['Dívidas e empréstimos','Dívidas & financiamentos'],false,true,'#B33A3A',172,array['financiamento'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.debt.agreements','Acordos / renegociações','expense.debt',array['Acordos','Renegociação','Renegociações'],array['Dívidas e empréstimos','Dívidas & financiamentos'],false,true,'#B33A3A',173,array['acordo','renegociacao'],true,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.debt.installments','Parcelamentos','expense.debt',array['Parcelamentos','Crediário'],array['Dívidas e empréstimos','Dívidas & financiamentos'],false,true,'#B33A3A',174,array['parcelamento','crediario'],true,'economic');

  -- Outros gastos
  perform private.ensure_system_category(p_space_id,'expense','expense.other','Outros gastos',null,array['Outros'],array[]::text[],false,false,'#6B6656',180,array['outros','outros gastos'],false,'economic');
  perform private.ensure_system_category(p_space_id,'expense','expense.other.other','Outros','expense.other',array[]::text[],array[]::text[],false,false,'#6B6656',181,array['outro','outros'],true,'economic');

  -- Receitas: hierarquia própria
  perform private.ensure_system_category(p_space_id,'income','income.root','Receitas',null,array[]::text[],array[]::text[],false,false,'#16816D',10,array['receita','renda'],false,'economic');
  perform private.ensure_system_category(p_space_id,'income','income.salary','Salário','income.root',array['Salário'],array[]::text[],true,false,'#16816D',11,array['salario','ordenado'],true,'economic');
  perform private.ensure_system_category(p_space_id,'income','income.salary_advance','Adiantamento salarial','income.root',array['Adiantamento'],array[]::text[],true,false,'#16816D',12,array['adiantamento','adiantamento salarial'],true,'economic');
  perform private.ensure_system_category(p_space_id,'income','income.freelance','Freelance / trabalho extra','income.root',array['Freelance'],array[]::text[],true,false,'#16816D',13,array['freela','freelance','trabalho extra'],true,'economic');
  perform private.ensure_system_category(p_space_id,'income','income.commissions','Comissões','income.root',array['Comissões'],array[]::text[],true,false,'#16816D',14,array['comissao','comissoes'],true,'economic');
  perform private.ensure_system_category(p_space_id,'income','income.bonus','Bônus / bonificação','income.root',array['Bonificação','Bônus'],array[]::text[],true,false,'#16816D',15,array['bonus','bonificacao'],true,'economic');
  perform private.ensure_system_category(p_space_id,'income','income.sale','Venda','income.root',array['Venda'],array[]::text[],true,false,'#16816D',16,array['venda'],true,'economic');
  perform private.ensure_system_category(p_space_id,'income','income.rent','Aluguel recebido','income.root',array[]::text[],array[]::text[],false,false,'#16816D',17,array['aluguel recebido','renda aluguel'],true,'economic');
  perform private.ensure_system_category(p_space_id,'income','income.investment_returns','Rendimentos de investimentos','income.root',array['Rendimentos'],array[]::text[],true,false,'#16816D',18,array['rendimento','investimento','dividendo','juros recebidos'],true,'economic');
  perform private.ensure_system_category(p_space_id,'income','income.gift','Presente recebido','income.root',array['Presente recebido'],array[]::text[],true,false,'#16816D',19,array['presente recebido'],true,'economic');
  perform private.ensure_system_category(p_space_id,'income','income.reimbursement','Reembolso recebido','income.root',array[]::text[],array[]::text[],false,false,'#16816D',20,array['reembolso recebido','reembolso'],true,'economic');
  perform private.ensure_system_category(p_space_id,'income','income.other','Outras receitas','income.root',array['Outras receitas'],array[]::text[],true,false,'#16816D',21,array['outra receita','outros recebimentos'],true,'economic');

  -- Estados/movimentações especiais: preservados por compatibilidade, mas fora da taxonomia econômica.
  perform private.ensure_system_category(p_space_id,'expense','special.unclassified','A classificar',null,array[]::text[],array[]::text[],false,false,'#8C8CA8',9999,array['a classificar','sem categoria'],false,'pending');
  perform private.ensure_system_category(p_space_id,'transfer','movement.transfer','Transferências',null,array['Transferência'],array[]::text[],false,false,'#7054B8',900,array['transferencia'],false,'movement');
  perform private.ensure_system_category(p_space_id,'transfer','movement.reserve','Reserva',null,array[]::text[],array[]::text[],false,false,'#7054B8',901,array['reserva'],false,'movement');
  perform private.ensure_system_category(p_space_id,'transfer','movement.investment','Investimentos',null,array[]::text[],array[]::text[],false,false,'#7054B8',902,array['investimento','aplicacao'],false,'movement');
  perform private.ensure_system_category(p_space_id,'transfer','movement.card_payment','Pagamento de cartão',null,array[]::text[],array[]::text[],false,false,'#7054B8',903,array['pagamento cartao','fatura'],false,'movement');
  perform private.ensure_system_category(p_space_id,'adjustment','movement.reimbursement','Reembolso',null,array[]::text[],array[]::text[],false,false,'#7054B8',904,array['reembolso','estorno'],false,'movement');

  -- This space keeps historical IDs while correcting classification choices.
  if p_space_id = '377e1085-1dfe-48a5-9546-30a6d91877b6'::uuid then
    update public.categories set parent_id = (select id from public.categories where space_id=p_space_id and system_key='expense.household'), updated_at=now()
    where space_id=p_space_id and system_key='expense.beauty.laundry';
    update public.categories set is_selectable=false, updated_at=now()
    where space_id=p_space_id and system_key in ('expense.shopping.online','expense.shopping.marketplace');
  end if;
end;
$function$;
