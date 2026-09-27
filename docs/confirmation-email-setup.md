# Confirmação de e-mail Fôlego

Template pronto: `supabase/email-templates/confirm-signup.pt-BR.html`.

**Ainda não ativado no Supabase Auth.** Um administrador deve abrir Supabase Dashboard → Authentication → Email Templates → Confirm signup, colar o HTML e salvar. Preserve `{{ .ConfirmationURL }}` sem alterações. Configure Site URL e Redirect URLs com o endereço final publicado do app, confirme SMTP e faça um cadastro com uma conta de teste antes de liberar usuários. Não coloque segredos no repositório nem use o e-mail pessoal do proprietário para testes públicos.
