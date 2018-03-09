with Alire.Properties;
with Alire.Requisites;
with Alire.Utils;

private with Ada.Containers.Indefinite_Holders;
private with Ada.Containers.Indefinite_Vectors;

generic
   type Values is private;
   with function "&" (L, R : Values) return Values;
   with function Image (V : Values) return String;
package Alire.Conditional_Values with Preelaborate is

   type Kinds is (Condition, Value, Vector);

   type Conditional_Value is tagged private;
   --  Recursive type that stores conditions (requisites) and values/further conditions if they are met or not

   function Evaluate (This : Conditional_Value; Against : Properties.Vector) return Values;
   --  Materialize against the given properties

   function Evaluate (This : Conditional_Value; Against : Properties.Vector) return Conditional_Value;
   --  Materialize against the given properties, returning values as an unconditional vector

   function Kind (This : Conditional_Value) return Kinds;

   function Is_Empty (This : Conditional_Value) return Boolean;

   function Empty return Conditional_Value;

   procedure Iterate_Children (This    : Conditional_Value;
                               Visitor : access procedure (CV : Conditional_Value));
   --  Visitor will be called for any immediate non-vector value
   --  Vector children will be iterated too, so a flat hierarchy will be mimicked for those

   function All_Values (This : Conditional_Value) return Values;
   --  Returns all values herein, both true and false, at any depth

   function Image_One_Line (This : Conditional_Value) return String;

   ---------------
   --  SINGLES  --
   ---------------

   function New_Value (V : Values) return Conditional_Value; -- when we don't really need a condition

   function Value (This : Conditional_Value) return Values
     with Pre => This.Kind = Value;

   ---------------
   --  VECTORS  --
   ---------------

   function "and" (L, R : Conditional_Value) return Conditional_Value;
   --  Concatenation

   --------------------
   --  CONDITIONALS  --
   --------------------

   function New_Conditional (If_X   : Requisites.Tree;
                             Then_X : Conditional_Value;
                             Else_X : Conditional_Value) return Conditional_Value;

   function Condition (This : Conditional_Value) return Requisites.Tree
     with Pre => This.Kind = Condition;

   function True_Value (This : Conditional_Value) return Conditional_Value
     with Pre => This.Kind = Condition;

   function False_Value (This : Conditional_Value) return Conditional_Value
     with Pre => This.Kind = Condition;

private

   type Inner_Node is abstract tagged null record;

   function Image (Node : Inner_Node) return String is abstract;

   function Image_Classwide (Node : Inner_Node'Class) return String is (Node.Image);

   function Kind (This : Inner_Node'Class) return Kinds;

   package Holders is new Ada.Containers.Indefinite_Holders (Inner_Node'Class);
   package Vectors is new Ada.Containers.Indefinite_Vectors (Positive, Inner_Node'Class);

   type Conditional_Value is new Holders.Holder with null record;
   --  Instead of dealing with pointers and finalization, we use this class-wide container

   type Value_Inner is new Inner_Node with record
      Value : Values;
   end record;

   overriding function Image (V : Value_Inner) return String is
      (Image (V.Value));

   type Vector_Inner is new Inner_Node with record
      Values : Vectors.Vector;
   end record;

   package Non_Primitive is
      function One_Liner is new Utils.Image_One_Line
        (Vectors,
         Vectors.Vector,
         Image_Classwide,
         " and ",
         "(empty condition)");
   end Non_Primitive;

   overriding function Image (V : Vector_Inner) return String is
     (Non_Primitive.One_Liner (V.Values));

   type Conditional_Inner is new Inner_Node with record
      Condition  : Requisites.Tree;
      Then_Value : Conditional_Value;
      Else_Value : Conditional_Value;
   end record;

   overriding function Image (V : Conditional_Inner) return String is
     ("when " & V.Condition.Image &
        " then " & V.Then_Value.Image_One_Line &
        " else " & V.Else_Value.Image_One_Line);

   --------------
   -- As_Value --
   --------------

   function As_Value (This : Conditional_Value) return Values
   is
     (Value_Inner (This.Constant_Reference.Element.all).Value)
   with Pre => This.Kind = Value;

   --------------------
   -- As_Conditional --
   --------------------

   function As_Conditional (This : Conditional_Value) return Conditional_Inner'Class is
     (Conditional_Inner'Class (This.Element))
   with Pre => This.Kind = Condition;

   ---------------
   -- As_Vector --
   ---------------

   function As_Vector (This : Conditional_Value) return Vectors.Vector is
     (Vector_Inner'Class (This.Element).Values)
       with Pre => This.Kind = Vector;

   ---------------------
   -- New_Conditional --
   ---------------------

   function New_Conditional (If_X   : Requisites.Tree;
                             Then_X : Conditional_Value;
                             Else_X : Conditional_Value) return Conditional_Value is
     (To_Holder (Conditional_Inner'(Condition  => If_X,
                                    Then_Value => Then_X,
                                    Else_Value => Else_X)));

   ---------------
   -- New_Value --
   ---------------

   function New_Value (V : Values) return Conditional_Value is
     (To_Holder (Value_Inner'(Value => V)));

   ---------------
   -- Condition --
   ---------------

   function Condition (This : Conditional_Value) return Requisites.Tree is
     (This.As_Conditional.Condition);

   -----------
   -- Value --
   -----------

   function Value (This : Conditional_Value) return Values renames As_Value;

   ----------------
   -- True_Value --
   ----------------

   function True_Value (This : Conditional_Value) return Conditional_Value is
      (This.As_Conditional.Then_Value);

   -----------------
   -- False_Value --
   -----------------

   function False_Value (This : Conditional_Value) return Conditional_Value is
      (This.As_Conditional.Else_Value);

   -----------
   -- Empty --
   -----------

   function Empty return Conditional_Value is
      (Holders.Empty_Holder with null record);

   --------------
   -- Is_Empty --
   --------------

   overriding function Is_Empty (This : Conditional_Value) return Boolean is
     (Holders.Holder (This).Is_Empty);

   ----------
   -- Kind --
   ----------

   function Kind (This : Inner_Node'Class) return Kinds is
     (if This in Value_Inner'Class
      then Value
      else (if This in Vector_Inner'Class
            then Vector
            else Condition));

   function Kind (This : Conditional_Value) return Kinds is
     (This.Constant_Reference.Kind);

   function Image_One_Line (This : Conditional_Value) return String is
     (if This.Is_Empty
      then "(empty condition)"
      else This.Constant_Reference.Image);

end Alire.Conditional_Values;