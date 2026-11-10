require "main"

Frame = 0

-- update e chamado 60 vezes por segundo. O firmware novo passa o numero
-- do quadro; se nao passar, contamos aqui mesmo.
function update(frame)
    Frame = Frame + 1
    loop(frame or Frame)
end
