provider "aws" {
  region = "us-east-1"
}

#criar no AWS e usar o arquivo pendente para subir a aplicação
variable "key_name" {
  default = "minha-chave"
}

resource "aws_security_group" "acervo_sg" {
  name        = "acervo-sg"
  description = "Libera HTTP e SSH"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "acervo_server" {
  ami                    = "ami-0c55b159cbfafe1f0"  
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.acervo_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y docker.io docker-compose
              systemctl start docker
              systemctl enable docker
              mkdir -p /home/ubuntu/app
              cd /home/ubuntu/app
              # Suba aqui o seu código (ideal seria clonar de um repositório Git)
              # Mas para simplificar, vamos criar os arquivos na mão via echo...
              # (Você pode substituir por git clone SEU-REPO)
              cat > Dockerfile << 'DOCKEREOF'
              FROM python:3.10-slim
              WORKDIR /app
              COPY requirements.txt .
              RUN pip install -r requirements.txt
              COPY . .
              RUN mkdir -p /app/data
              EXPOSE 5000
              CMD ["python", "app.py"]
              DOCKEREOF

              cat > requirements.txt << 'REQEOF'
              flask
              flask_sqlalchemy
              REQEOF

              cat > app.py << 'PYEOF'
              from flask import Flask, render_template, request, redirect
              from flask_sqlalchemy import SQLAlchemy
              import os

              app = Flask(__name__)
              db_path = os.path.join(os.path.dirname(__file__), 'data', 'acervo.db')
              os.makedirs(os.path.dirname(db_path), exist_ok=True)
              app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{db_path}'
              app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
              db = SQLAlchemy(app)

              class Item(db.Model):
                  id = db.Column(db.Integer, primary_key=True)
                  nome = db.Column(db.String(200), nullable=False)
                  tipo = db.Column(db.String(50))

              @app.route('/')
              def home():
                  itens = Item.query.all()
                  return render_template('index.html', itens=itens)

              @app.route('/adicionar', methods=['POST'])
              def adicionar():
                  nome = request.form['nome']
                  tipo = request.form['tipo']
                  novo = Item(nome=nome, tipo=tipo)
                  db.session.add(novo)
                  db.session.commit()
                  return redirect('/')

              if __name__ == '__main__':
                  with app.app_context():
                      db.create_all()
                  app.run(host='0.0.0.0', port=5000)
              PYEOF

              mkdir -p templates
              cat > templates/index.html << 'HTMLEOF'
              <!DOCTYPE html>
              <html lang="pt-br">
              <head>
                  <meta charset="UTF-8">
                  <title>Meu Acervo</title>
                  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
              </head>
              <body class="bg-light">
                  <div class="container mt-5">
                      <h1 class="mb-4">📚 Meu Acervo Pessoal</h1>
                      <form action="/adicionar" method="post" class="row g-3 mb-4">
                          <div class="col-md-4">
                              <input type="text" name="nome" class="form-control" placeholder="Nome do item" required>
                          </div>
                          <div class="col-md-3">
                              <select name="tipo" class="form-select">
                                  <option value="Livro">Livro</option>
                                  <option value="CD">CD</option>
                                  <option value="DVD">DVD</option>
                                  <option value="Outro">Outro</option>
                              </select>
                          </div>
                          <div class="col-md-2">
                              <button type="submit" class="btn btn-success">Adicionar</button>
                          </div>
                      </form>
                      <table class="table table-striped">
                          <thead><tr><th>ID</th><th>Nome</th><th>Tipo</th></tr></thead>
                          <tbody>{% for item in itens %}<tr><td>{{ item.id }}</td><td>{{ item.nome }}</td><td>{{ item.tipo }}</td></tr>{% endfor %}</tbody>
                      </table>
                      {% if not itens %}<p class="text-muted">Nenhum item cadastrado ainda. Adicione o primeiro!</p>{% endif %}
                  </div>
              </body>
              </html>
              HTMLEOF

              # Constrói e sobe o container com volume para persistência
              docker build -t acervo .
              docker run -d -p 80:5000 -v /home/ubuntu/acervo_data:/app/data acervo
              EOF

  tags = {
    Name = "EstanteMagica"
  }
}

output "ip_publico" {
  value = aws_instance.acervo_server.public_ip
}