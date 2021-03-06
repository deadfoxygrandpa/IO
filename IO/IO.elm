module IO.IO where

-- | User-facing API

-- | IO Actions
putChar : Char -> IO ()
putChar c = Impure (PutC c (Pure ()))

getChar : IO Char
getChar = Impure (GetC Pure)

exit : Int -> IO ()
exit = Impure . Exit

putStr : String -> IO ()
putStr = mapIO putChar . String.toList

putStrLn : String -> IO ()
putStrLn s = putStr s >> putChar '\n'

readUntil : Char -> IO String
readUntil end = let go s = getChar >>= \c ->
                           if c == end
                           then pure s
                           else go (String.append s (String.cons c ""))
                in go ""

getLine : IO String
getLine = readUntil '\n'

-- | IO Combinators
map : (a -> b) -> IO a -> IO b
map f io = case io of
  Pure   a   -> Pure (f a)
  Impure iof -> Impure (mapF (map f) iof)

mapIO : (a -> IO ()) -> [a] -> IO ()
mapIO f xs = foldr ((>>) . f) (pure ()) xs

pure : a -> IO a
pure = Pure

apply : IO (a -> b) -> IO a -> IO b
apply iof iom = iof >>= \f ->
                iom >>= \m ->
                pure (f m)

(<*>) : IO (a -> b) -> IO a -> IO b
(<*>) = apply

bind : IO a -> (a -> IO b) -> IO b
bind io f = case io of
  Pure x     -> f x
  Impure iof -> Impure (mapF (flip bind f) iof)

(>>=) : IO a -> (a -> IO b) -> IO b
(>>=) = bind

seq : IO a -> IO b -> IO b
seq x y = x >>= \_ -> y

(>>) : IO a -> IO b -> IO b
(>>) = seq

-- Has to be >>= not >> because of strictness!
forever : IO a -> IO ()
forever m = m >>= (\_ -> forever m)

data IOF a = PutC Char a      -- ^ the a is the next computation
           | GetC (Char -> a) -- ^ the (Char -> a) is the continuation
           | Exit Int         -- ^ since there is no parameter, this must terminate

data IO a = Pure a
          | Impure (IOF (IO a))

mapF : (a -> b) -> IOF a -> IOF b
mapF f iof = case iof of
  PutC p x -> PutC p (f x)
  GetC k   -> GetC (f . k)
  Exit n   -> Exit n

-- | Not actually used, but maybe can be for the interpreter?
foldIO : (a -> b) -> (IOF b -> b) -> IO a -> b
foldIO pur impur io = case io of
  Pure   x   -> pur x
  Impure iof -> impur (mapF (foldIO pur impur) iof)
