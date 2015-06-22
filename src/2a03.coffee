class CPU

  ###
  16k ram
  Bytes, Words, Addressing:
  8 bit bytes, 16 bit words in lobyte-hibyte representation (Little-Endian).
  16 bit address range, operands follow instruction codes.
  ###
  RAM_SIZE: 0xFFFF

  #Constants for reset and init.
  SP_INIT_VAL: 0xFD
  PC_INIT_VAL: 0xFFFC

  #Stack LIFO, top down, 8 bit range, 0x0100 - 0x01FF
  BASE_STACK_ADDR: 0x100

  #interrupt vector table
  VECTOR_TABLE: {
    NMI: 0xFFFA,
    RST: 0xFFFC,
    IRQ: 0xFFFE
  }

  READ_LENGTH: {
    L: 8,
    HL: 16
  }

  ADDRESSING_MODE: {
    ACCUMULATOR: 'ACC',
    IMMEDIATE: 'IMM',
    IMPLIED: 'IMP'
  }

  constructor: (@ram = [])  ->
    for x in [0..CPU::RAM_SIZE]
      @ram[x] = 0;

    ##registers
    @PC = CPU::PC_INIT_VAL ##Program Counter
    @AC = 0 ##Accumulator
    @XR = 0 ##X Register
    @YR = 0 ##Y Register
    @SR = 0 ##Status Register
    @SP = CPU::SP_INIT_VAL ##Stack Pointer
    @N = 0 ##Negative
    @V = 0 ##Overflow
    @U = 1 ##ignored
    @B = 0 ##Break
    @D = 0 ##Decimal
    @I = 0 ##Interrupt (IRQ disable)
    @Z = 0 ##Zero
    @C = 0 ##Carry

    @cycles = 0

  #reset pc
  init: () ->
    @PC = @PC_INIT_VAL
    @SP = @SP_INIT_VAL
    @cycles = 0

  #clear ram
  clear: () ->
    for x in [0..CPU::RAM_SIZE]
      @ram[x] = 0;

  #Little-end read
  read: (address, readingLength) ->
    if readingLength == CPU::READ_LENGTH.HL
      l = @ram[address];
      h = @ram[address + 1];
      h << 8 | l
    else @ram[address];

  ###
    Stack operations
  ###

  #push stack
  push: (value) ->
    if value > 0xFF
      @push(value >> 8) #High 8
      @push(value & 0xFF)#Low 8
    else
      @ram[CPU::BASE_STACK_ADDR + @SP] = value
      @SP--
      @SP &= 0xFF #overflow

  pop: () ->
    @SP++
    @SP &= 0xFF #overflow
    @ram[CPU::BASE_STACK_ADDR + @SP]

  #status register
  getSR: () ->
    @N << 7 | @V << 6 | @U << 5 | @B << 4 | @D << 3 | @I << 2 | @Z << 1 | @C

  setSR: (SR) ->
    @N = SR >> 7 & 0x1
    @V = SR >> 6 & 0x1
    @U = SR >> 5 & 0x1
    @B = SR >> 4 & 0x1
    @D = SR >> 3 & 0x1
    @I = SR >> 2 & 0x1
    @Z = SR >> 1 & 0x1
    @C = SR & 0x1

  ###
   Interruption
  ###
  interrupt: (interruptType) ->
    @push(@PC)
    @push(@getSR())
    @PC = @read(interruptType, CPU::READ_LENGTH.HL)
    @I = 1
    @cycles += 7

  #NMI Non-Maskable Interrupt
  NMI: () ->
    @interrupt(CPU::VECTOR_TABLE.NMI)

  #IRQ
  IRQ: () ->
    if @I == 0
      @interrupt(CPU::VECTOR_TABLE.IRQ)

  #reset
  RST: () ->
    @interrupt(CPU::VECTOR_TABLE.RST)

  printRegisters: ()->
    console.log 'AC=', @AC, '(= BDC', @AC.toString(16), ') V=', @V, 'C=', @C, 'N=', @N, 'Z=', @Z

  ###
    Addressing modes
  ###
  #A		....	Accumulator	 	OPC A	 	operand is AC
  accumulator: () -> {operand: @AC, address: CPU::ADDRESSING_MODE.ACCUMULATOR, bytes: 0}

  #abs		....	absolute	 	OPC $HHLL	 	operand is address $HHLL
  absolute: (oper) -> {operand: @ram[oper], address: oper, bytes: 2}

  #abs,X		....	absolute, X-indexed	 	OPC $HHLL,X	 	operand is address incremented by X with carry
  absoluteX: (oper) -> {operand: @ram[oper + @XR], address: oper + @XR, bytes: 2}

  #abs,Y		....	absolute, Y-indexed	 	OPC $HHLL,Y	 	operand is address incremented by Y with carry
  absoluteY: (oper) -> {operand: @ram[oper + @YR], address: oper + @YR, bytes: 2}

  # #		....	immediate	 	OPC #$BB	 	operand is byte (BB)
  immediate: (oper) -> {operand: oper, address: CPU::ADDRESSING_MODE.IMMEDIATE, bytes: 1}

  #impl		....	implied	 	OPC	 	operand implied
  implied: (oper) -> {operand: @AC, address: CPU::ADDRESSING_MODE.IMPLIED, bytes: 0}

  #ind		....	indirect	 	OPC ($HHLL)	 	operand is effective address; effective address is value of address
  indirect: (oper) -> {operand: @ram[@ram[oper]], address: @ram[oper], bytes: 2}

  #X,ind		....	X-indexed, indirect	 	OPC ($BB,X)
  # operand is effective zeropage address; effective address is byte (BB) incremented by X without carry
  indirectX: (oper) -> {operand: @ram[@ram[(oper & 0x00FF) + @XR]], address: @ram[(oper & 0x00FF) + @XR], bytes: 1}

  #ind,Y		....	indirect, Y-indexed	 	OPC ($LL),Y
  # operand is effective address incremented by Y with carry; effective address is word at zeropage address
  indirectY: (oper) -> {operand: @ram[@ram[(oper & 0x00FF) + @YR]], address: @ram[(oper & 0x00FF) + @YR], bytes: 1}

  #rel		....	relative	 	OPC $BB	 	branch target is PC + offset (BB), bit 7 signifies negative offset
  relative: (oper) -> {operand: @ram[@PC + oper], address: @PC + oper, bytes: 1}

  #zpg		....	zeropage	 	OPC $LL	 	operand is of address; address hibyte : zero ($00xx)
  zeropage: (oper) -> {operand: @ram[oper & 0x00FF], address: oper & 0x00FF, bytes: 1}

  #zpg,X		....	zeropage, X-indexed	 	OPC $LL,X
  # operand is address incremented by X; address hibyte : zero ($00xx); no page transition
  zeropageX: (oper) -> {operand: @ram[(oper + @XR) & 0x00FF], address: oper + @XR, bytes: 1};

  #zpg,Y		....	zeropage, Y-indexed	 	OPC $LL,Y
  # operand is address incremented by Y; address hibyte : zero ($00xx); no page transition
  zeropageY: (oper) -> {operand: @ram[(oper + @YR) & 0x00FF], address: oper + @YR, bytes: 1};

  addressing: () ->
    if arguments.length == 2
      return arguments[1]
    else
      return @immediate

  ##cpu step info
  @stepInfo: {
    operand: 0x00,
    addressMode: null
  }

  step: () ->
    operand = @ram[@PC]
    @stepInfo.operand = operand
    @stepInfo.addressMode = @immediate(operand)


  accumulate: (src, dst, carry) ->
    return src + dst + carry;

  compare: (src, dest) ->
    diff = src - dest
    @setZN(diff)
    if diff >= 0
      @C = 1
    else
      @C = 0
    return diff

  setZ: (oper) ->
    @Z = if oper == 0 then 1 else 0;

  setN: (oper) ->
    @N = if (oper & 0x80) != 0 then 1 else 0;

  setZN: (oper) ->
    @setZ(oper)
    @setN(oper)

  addCycleOnBranch: (stepInfo) ->
    @cycles += 1;

  run: () ->

    #response interruption

    oprcode = @ram[@PC]
    oprcodeInfo = CPU::OPRCODES[oprcode]
    console.log "OPC:", oprcodeInfo.desc
    instruction = oprcodeInfo.instruction
    addressMode = oprcodeInfo.addressMode.call(this, (oprcode + 1))
    instruction.call(this, {addressMode : addressMode, operand : addressMode.operand})

    #increase PC
    @PC += (addressMode.bytes + 1)


  ###
    Instructions
  ###

  CLD: () ->
    @D = 0

  LDA: (oper) ->
    @AC = @addressing(arguments)(oper)


  ###
  ADC  Add Memory to Accumulator with Carry

     A + M + C -> A, C                N Z C I D V
                                      + + + - - +

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     immidiate     ADC #oper     69    2     2
     zeropage      ADC oper      65    2     3
     zeropage,X    ADC oper,X    75    2     4
     absolute      ADC oper      6D    3     4
     absolute,X    ADC oper,X    7D    3     4*
     absolute,Y    ADC oper,Y    79    3     4*
     (indirect,X)  ADC (oper,X)  61    2     6
     (indirect),Y  ADC (oper),Y  71    2     5*
  ###
  ADC: (stepInfo) ->
    operand = stepInfo.operand

    @AC = @accumulate(operand, @AC, @C)

    console.log '@AC', @AC

    @C = if @AC > 0xFF then 1 else 0;

    @setZN(@AC)

    H4b = @AC / 0x10
    @V = if H4b >= -8 & H4b <= 7 then 0 else 1;
    if @V == 1
      console.warn('High 4 bit', H4b.toString(16), 'is not in rage(-8~7). Overflow!!')
    console.log('@H4b is', H4b.toString(16))

    @AC = @AC & 0xFF;

    @printRegisters()

  ###
  AND Memory with Accumulator

     A AND M -> A                     N Z C I D V
                                      + + - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     immidiate     AND #oper     29    2     2
     zeropage      AND oper      25    2     3
     zeropage,X    AND oper,X    35    2     4
     absolute      AND oper      2D    3     4
     absolute,X    AND oper,X    3D    3     4*
     absolute,Y    AND oper,Y    39    3     4*
     (indirect,X)  AND (oper,X)  21    2     6
     (indirect),Y  AND (oper),Y  31    2     5*
  ###
  AND: (stepInfo) ->
    operand = stepInfo.operand
    @AC = @AC & operand & 0xFF
    @setZN(@AC)

  ###
  ASL  Shift Left One Bit (Memory or Accumulator)

     C <- [76543210] <- 0             N Z C I D V
                                      + + + - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     accumulator   ASL A         0A    1     2
     zeropage      ASL oper      06    2     5
     zeropage,X    ASL oper,X    16    2     6
     absolute      ASL oper      0E    3     6
     absolute,X    ASL oper,X    1E    3     7
   ###
  ASL: (stepInfo) ->
    operand = stepInfo.operand
    addressingMode = stepInfo.addressMode

    @C = (operand >> 7) & 1
    operand <<= 1

    if addressingMode.address == CPU::ADDRESSING_MODE.ACCUMULATOR
      @AC = operand
    else
      @ram[operand]

    @setZN operand

  ###
    BCC  Branch on Carry Clear

     branch on C = 0                  N Z C I D V
                                      - - - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     relative      BCC oper      90    2     2**

  ###
  BCC: (stepInfo) ->
    if @C == 0
      @PC = stepInfo.addressMode.address;
      @addCycleOnBranch stepInfo

  ###
    BCS  Branch on Carry Set

     branch on C = 1                  N Z C I D V
                                      - - - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     relative      BCS oper      B0    2     2**
  ###
  BCS: (stepInfo)->
    if @C == 1
      @PC = stepInfo.addressMode.address;
      @addCycleOnBranch stepInfo;

  ###
    BEQ  Branch on Result Zero

     branch on Z = 1                  N Z C I D V
                                      - - - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     relative      BEQ oper      F0    2     2**
  ###
  BEQ: (stepInfo) ->
    if @Z == 1
      @PC = stepInfo.addressMode.address;
      @addCycleOnBranch stepInfo;

  ###
    BIT  Test Bits in Memory with Accumulator

     bits 7 and 6 of operand are transfered to bit 7 and 6 of SR (N,V);
     the zeroflag is set to the result of operand AND accumulator.

     A AND M, M7 -> N, M6 -> V        N Z C I D V
                                     M7 + - - - M6

     addressing    assembler    opc  bytes  cycles
     --------------------------------------------
     zeropage      BIT oper      24    2     3
     absolute      BIT oper      2C    3     4

  ###
  BIT: (stepInfo) ->
    console.log stepInfo
    @N = stepInfo.operand >> 7 & 1
    @V = stepInfo.operand >> 6 & 1
    @Z = stepInfo.operand & @AC

  ###
    BMI  Branch on Result Minus

     branch on N = 1                  N Z C I D V
                                      - - - - - -

     addressing    assembler    opc  bytes  cycles
     --------------------------------------------
     relative      BMI oper      30    2     2**
  ###
  BMI: (stepInfo) ->
    if @N == 1
      @PC = stepInfo.addressMode.address;
      @addCycleOnBranch stepInfo;

  ###
    BNE  Branch on Result not Zero

     branch on Z = 0                  N Z C I D V
                                      - - - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     relative      BNE oper      D0    2     2**
  ###
  BNE: (stepInfo) ->
    if @Z == 0
      @PC = stepInfo.addressMode.address;
      @addCycleOnBranch stepInfo;

  ###
    BPL  Branch on Result Plus

     branch on N = 0                  N Z C I D V
                                      - - - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     relative      BPL oper      10    2     2**

  ###
  BPL: (stepInfo) ->
    if @N == 0
      @PC = stepInfo.addressMode.address;
      @addCycleOnBranch stepInfo;

  ###
    BRK  Force Break

      interrupt,                       N Z C I D V
      push PC+2, push SR               - - - 1 - -

        addressing    assembler    opc  bytes  cycles
      --------------------------------------------
      implied       BRK           00    1     7
  ###
  BRK: (stepInfo) ->
    @interrupt(CPU::VECTOR_TABLE.NMI)



  ###
    BVC  Branch on Overflow Clear

      branch on V = 0                  N Z C I D V
    - - - - - -

    addressing    assembler    opc  bytes  cycles
    --------------------------------------------
    relative      BVC oper      50    2     2**

  ###
  BVC: (stepInfo) ->
    if @V == 0
      @PC = stepInfo.addressMode.address;
      @addCycleOnBranch stepInfo;

  ###
    BVS  Branch on Overflow Set

    branch on V = 1                  N Z C I D V
  - - - - - -

  addressing    assembler    opc  bytes  cycles
  --------------------------------------------
  relative      BVC oper      70    2     2**
  ###
  BVS: (stepInfo) ->
    if @V == 1
      @PC = stepInfo.addressMode.address;
      @addCycleOnBranch stepInfo;

  ###
      CLC  Clear Carry Flag

        0 -> C                           N Z C I D V
    - - 0 - - -

    addressing    assembler    opc  bytes  cycles
    --------------------------------------------
    implied       CLC           18    1     2
  ###
  CLC: (stepInfo) ->
    @C = 0
    @cycles += 2

  ###
  CLI  Clear Interrupt Disable Bit

     0 -> I                           N Z C I D V
                                      - - - 0 - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     implied       CLI           58    1     2
  ###
  CLI: (stepInfo) ->
    @I = 0
    @cycles += 2

  ###
  CLV  Clear Overflow Flag

     0 -> V                           N Z C I D V
                                      - - - - - 0

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     implied       CLV           B8    1     2
  ###
  CLV: (stepInfo) ->
    @V = 0
    @cycles += 2

  ###
    CMP  Compare Memory with Accumulator

      A - M                            N Z C I D V
                                       + + + - - -

    addressing    assembler    opc  bytes  cyles
    --------------------------------------------
    immidiate     CMP #oper     C9    2     2
    zeropage      CMP oper      C5    2     3
    zeropage,X    CMP oper,X    D5    2     4
    absolute      CMP oper      CD    3     4
    absolute,X    CMP oper,X    DD    3     4*
    absolute,Y    CMP oper,Y    D9    3     4*
    (indirect,X)  CMP (oper,X)  C1    2     6
    (indirect),Y  CMP (oper),Y  D1    2     5*
  ###
  CMP: (stepInfo) ->
    @compare(@AC, stepInfo.operand)
  ###
  CPX  Compare Memory and Index X

      X - M                            N Z C I D V
                                       + + + - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  immidiate     CPX #oper     E0    2     2
  zeropage      CPX oper      E4    2     3
  absolute      CPX oper      EC    3     4
  ###
  CPX: (stepInfo) ->
    @compare(@XR, stepInfo.operand)

  ###
  CPY  Compare Memory and Index Y

      Y - M                            N Z C I D V
                                       + + + - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  immidiate     CPY #oper     C0    2     2
  zeropage      CPY oper      C4    2     3
  absolute      CPY oper      CC    3     4
  ###
  CPY: (stepInfo) ->
    @compare(@YR, stepInfo.operand)

  ###
  DEC  Decrement Memory by One

     M - 1 -> M                       N Z C I D V
                                      + + - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     zeropage      DEC oper      C6    2     5
     zeropage,X    DEC oper,X    D6    2     6
     absolute      DEC oper      CE    3     3
     absolute,X    DEC oper,X    DE    3     7
  ###
  DEC: (stepInfo) ->
    decreased = stepInfo.operand - 1
    @ram[stepInfo.addressMode.address] = decreased
    @setZN(decreased)

  ###
  DEX  Decrement Index X by One

       X - 1 -> X                       N Z C I D V
                                        + + - - - -

       addressing    assembler    opc  bytes  cyles
       --------------------------------------------
       implied       DEC           CA    1     2

  ###
  DEX: (stepInfo) ->
    @setZN(@XR--)

  ###
  DEY  Decrement Index Y by One

     Y - 1 -> Y                       N Z C I D V
                                      + + - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     implied       DEC           88    1     2

  ###
  DEY: (stepInfo) ->
    @setZN(@YR--)

  ###
  EOR  Exclusive-OR Memory with Accumulator

   A EOR M -> A                     N Z C I D V
                                    + + - - - -

   addressing    assembler    opc  bytes  cyles
   --------------------------------------------
   immidiate     EOR #oper     49    2     2
   zeropage      EOR oper      45    2     3
   zeropage,X    EOR oper,X    55    2     4
   absolute      EOR oper      4D    3     4
   absolute,X    EOR oper,X    5D    3     4*
   absolute,Y    EOR oper,Y    59    3     4*
   (indirect,X)  EOR (oper,X)  41    2     6
   (indirect),Y  EOR (oper),Y  51    2     5*
  ###
  EOR: (stepInfo) ->
    @AC ^= stepInfo.operand
    @AC &= 0xFF
    @setZN(@AC)

  ###
  INC  Increment Memory by One

  M + 1 -> M                       N Z C I D V
                                  + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  zeropage      INC oper      E6    2     5
  zeropage,X    INC oper,X    F6    2     6
  absolute      INC oper      EE    3     6
  absolute,X    INC oper,X    FE    3     7
  ###
  INC: (stepInfo) ->
    increased = stepInfo.operand + 1
    @ram[stepInfo.addressMode.address] = increased
    @setZN(increased)
  ###
  INX  Increment Index X by One

  X + 1 -> X                       N Z C I D V
                                  + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       INX           E8    1     2
  ###
  INX: (stepInfo) ->
    @setZN(@XR++)
  ###

  INY  Increment Index Y by One

  Y + 1 -> Y                       N Z C I D V
                                  + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       INY           C8    1     2
  ###
  INY: (stepInfo) ->
    @setZN(@YR++)

  ###

  JMP  Jump to New Location

  (PC+1) -> PCL                    N Z C I D V
  (PC+2) -> PCH                    - - - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  absolute      JMP oper      4C    3     3
  indirect      JMP (oper)    6C    3     5
  ###
  JMP: (stepInfo) ->
    @PC = stepInfo.operand

  ###

  JSR  Jump to New Location Saving Return Address

  push (PC+2),                     N Z C I D V
  (PC+1) -> PCL                    - - - - - -
  (PC+2) -> PCH

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  absolute      JSR oper      20    3     6
  ###
  JSR: (stepInfo) ->
    @push(@PC)
    @PC = stepInfo.operand

  ###
  LDX  Load Index X with Memory

  M -> X                           N Z C I D V
                                   + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  immidiate     LDX #oper     A2    2     2
  zeropage      LDX oper      A6    2     3
  zeropage,Y    LDX oper,Y    B6    2     4
  absolute      LDX oper      AE    3     4
  absolute,Y    LDX oper,Y    BE    3     4*
  ###
  LDX: (stepInfo) ->
    @XR = stepInfo.operand
    @setZN(@XR)
  ###

  LDY  Load Index Y with Memory

  M -> Y                           N Z C I D V
                                   + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  immidiate     LDY #oper     A0    2     2
  zeropage      LDY oper      A4    2     3
  zeropage,X    LDY oper,X    B4    2     4
  absolute      LDY oper      AC    3     4
  absolute,X    LDY oper,X    BC    3     4*
  ###
  LDY: (stepInfo) ->
    @YR = stepInfo.operand
    @setZN(@YR)

  ###
  LSR  Shift One Bit Right (Memory or Accumulator)

  0 -> [76543210] -> C             N Z C I D V
                                   - + + - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  accumulator   LSR A         4A    1     2
  zeropage      LSR oper      46    2     5
  zeropage,X    LSR oper,X    56    2     6
  absolute      LSR oper      4E    3     6
  absolute,X    LSR oper,X    5E    3     7
  ###
  LSR: (stepInfo) ->
    operand = stepInfo.operand
    addressingMode = stepInfo.addressMode

    @C = operand & 1
    operand >>= 1

    if addressingMode.address == CPU::ADDRESSING_MODE.ACCUMULATOR
      @AC = operand
    else
      @ram[operand]

    @setZN operand


  ###

  NOP  No Operation

  ---                              N Z C I D V
                                - - - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       NOP           EA    1     2
  ###
  NOP: (stepInfo) ->
    #Noop

    ###

    ORA  OR Memory with Accumulator

    A OR M -> A                      N Z C I D V
                                  + + - - - -

    addressing    assembler    opc  bytes  cyles
    --------------------------------------------
    immidiate     ORA #oper     09    2     2
    zeropage      ORA oper      05    2     3
    zeropage,X    ORA oper,X    15    2     4
    absolute      ORA oper      0D    3     4
    absolute,X    ORA oper,X    1D    3     4*
    absolute,Y    ORA oper,Y    19    3     4*
    (indirect,X)  ORA (oper,X)  01    2     6
    (indirect),Y  ORA (oper),Y  11    2     5*
    ###
  ORA: (stepInfo) ->
    @AC |= stepInfo.operand
    @setZN(@AC)

  ###

  PHA  Push Accumulator on Stack

  push A                           N Z C I D V
                                - - - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       PHA           48    1     3
  ###
  PHA: (stepInfo) ->
    @push(@AC)

  ###

  PHP  Push Processor Status on Stack

  push SR                          N Z C I D V
                                - - - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       PHP           08    1     3
  ###
  PHP: (stepInfo) ->
    @push(@getSR())

  ###

  PLA  Pull Accumulator from Stack

  pull A                           N Z C I D V
                                + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       PLA           68    1     4
  ###
  PLA: (stepInfo) ->
    @AC = @pop()
    @setZN(@AC)

  ###

  PLP  Pull Processor Status from Stack

  pull SR                          N Z C I D V
                                from stack

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       PHP           28    1     4
  ###
  PLP: (stepInfo) ->
    sr = @pop()
    @setSR(sr)

  ###

  ROL  Rotate One Bit Left (Memory or Accumulator)

  C <- [76543210] <- C             N Z C I D V
                                + + + - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  accumulator   ROL A         2A    1     2
  zeropage      ROL oper      26    2     5
  zeropage,X    ROL oper,X    36    2     6
  absolute      ROL oper      2E    3     6
  absolute,X    ROL oper,X    3E    3     7
  ###
  ROL: (stepInfo) ->
    operand = stepInfo.operand
    addressingMode = stepInfo.addressMode

    @C = (operand >> 7) & 1
    operand <<= 1
    operand += @C

    #console.log(stepInfo,'1',addressingMode.address)

    if addressingMode.address == CPU::ADDRESSING_MODE.ACCUMULATOR
      @AC = operand
    else
      @ram[operand]

    @setZN operand

  ###

  ROR  Rotate One Bit Right (Memory or Accumulator)

  C -> [76543210] -> C             N Z C I D V
                                + + + - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  accumulator   ROR A         6A    1     2
  zeropage      ROR oper      66    2     5
  zeropage,X    ROR oper,X    76    2     6
  absolute      ROR oper      6E    3     6
  absolute,X    ROR oper,X    7E    3     7
  ###
  ROR: (stepInfo) ->
    operand = stepInfo.operand
    addressingMode = stepInfo.addressMode

    topBit = operand & 1
    operand >>= 1
    operand += (topBit << 7)
    @C = topBit

    #console.log(stepInfo,'1',addressingMode.address)

    if addressingMode.address == CPU::ADDRESSING_MODE.ACCUMULATOR
      @AC = operand
    else
      @ram[operand]

    @setZN operand
  ###

  RTI  Return from Interrupt

  pull SR, pull PC                 N Z C I D V
                                from stack

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       RTI           40    1     6
  ###
  RTI: (stepInfo) ->
    @setSR(@pop())
    @PC = @pop()

  ###

  RTS  Return from Subroutine

  pull PC, PC+1 -> PC              N Z C I D V
                                - - - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       RTS           60    1     6
  ###
  RTS: (stepInfo) ->
    @PC = @pop() + 1

  ###

  SBC  Subtract Memory from Accumulator with Borrow

  A - M - C -> A                   N Z C I D V
                                + + + - - +

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  immidiate     SBC #oper     E9    2     2
  zeropage      SBC oper      E5    2     3
  zeropage,X    SBC oper,X    F5    2     4
  absolute      SBC oper      ED    3     4
  absolute,X    SBC oper,X    FD    3     4*
  absolute,Y    SBC oper,Y    F9    3     4*
  (indirect,X)  SBC (oper,X)  E1    2     6
  (indirect),Y  SBC (oper),Y  F1    2     5*
  ###
  SBC: (stepInfo) ->
    operand = -stepInfo.operand

    @AC = @accumulate(operand, @AC, @C)

    console.log '@AC', @AC

    @C = if @AC > 0xFF then 1 else 0;

    @setZN(@AC)

    H4b = @AC / 0x10
    @V = if H4b >= -8 & H4b <= 7 then 0 else 1;
    if @V == 1
      console.warn('High 4 bit', H4b.toString(16), 'is not in range(-8~7). Overflow!!')
      console.log('@H4b is', H4b.toString(16))

    @AC = @AC & 0xFF;

  ###

  SEC  Set Carry Flag

  1 -> C                           N Z C I D V
                                   - - 1 - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       SEC           38    1     2
  ###
  SEC: () ->
    @C = 1

  ###
  SED  Set Decimal Flag

  1 -> D                           N Z C I D V
                                   - - - - 1 -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       SED           F8    1     2
  ###
  SED: () ->
    @D = 1
  ###

  SEI  Set Interrupt Disable Status

  1 -> I                           N Z C I D V
                                - - - 1 - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       SEI           78    1     2
  ###
  SEI: (stepInfo) ->
    @I = 1

  ###

  STA  Store Accumulator in Memory

  A -> M                           N Z C I D V
                                   - - - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  zeropage      STA oper      85    2     3
  zeropage,X    STA oper,X    95    2     4
  absolute      STA oper      8D    3     4
  absolute,X    STA oper,X    9D    3     5
  absolute,Y    STA oper,Y    99    3     5
  (indirect,X)  STA (oper,X)  81    2     6
  (indirect),Y  STA (oper),Y  91    2     6
  ###
  STA: (stepInfo) ->
    @ram[stepInfo.addressMode.address] = @AC

  ###

  STX  Store Index X in Memory

  X -> M                           N Z C I D V
                                - - - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  zeropage      STX oper      86    2     3
  zeropage,Y    STX oper,Y    96    2     4
  absolute      STX oper      8E    3     4
  ###
  STX: (stepInfo) ->
    @ram[stepInfo.addressMode.address] = @XR
  ###

  STY  Sore Index Y in Memory

  Y -> M                           N Z C I D V
                                   - - - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  zeropage      STY oper      84    2     3
  zeropage,X    STY oper,X    94    2     4
  absolute      STY oper      8C    3     4
  ###
  STY: (stepInfo) ->
    @ram[stepInfo.addressMode.address] = @YR
  ###

  TAX  Transfer Accumulator to Index X

  A -> X                           N Z C I D V
                                   + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       TAX           AA    1     2
  ###
  TAX: (stepInfo) ->
    @XR = @AC
    @setZN(@XR)

  ###

  TAY  Transfer Accumulator to Index Y

  A -> Y                           N Z C I D V
                                + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       TAY           A8    1     2
  ###
  TAY: (stepInfo) ->
    @YR = @AC
    @setZN(@YR)

  ###

  TSX  Transfer Stack Pointer to Index X

  SP -> X                          N Z C I D V
                                + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       TSX           BA    1     2
  ###
  TSX: (stepInfo) ->
    @XR = @SP
    @setZN(@XR)

  ###

  TXA  Transfer Index X to Accumulator

  X -> A                           N Z C I D V
                                + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       TXA           8A    1     2
  ###
  TXA: (stepInfo) ->
    @AC = @R
    @setZN(@AC)

  ###

  TXS  Transfer Index X to Stack Register

  X -> SP                          N Z C I D V
                                + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       TXS           9A    1     2
  ###
  TXS: (stepInfo) ->
    @SP = @XR
    @setZN(@SP)

  ###

  TYA  Transfer Index Y to Accumulator

  Y -> A                           N Z C I D V
                                + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       TYA           98    1     2

  ###
  TYA: (stepInfo) ->
    @AC = @YR
    @setZN(@AC)


  OPRCODES: {
    0x00: {instruction: CPU::BRK, text : 'BRK', addressMode: CPU::implied, desc :'BRK implied'},
    0x01: {instruction: CPU::ORA, text : 'ORA', addressMode: CPU::indirect, desc :'ORA indirect'},
  #0x03: { instruction : CPU::SLO,addressMode : CPU::indirect},
  #0x04: { instruction : CPU::NOP,addressMode : CPU::zeropage},
    0x05: {instruction: CPU::ORA, text : 'ORA', addressMode: CPU::zeropage, desc :'ORA zeropage'},
    0x06: {instruction: CPU::ASL, text : 'ASL', addressMode: CPU::zeropage, desc :'ASL zeropage'},
  #0x07: { instruction : CPU::SLO,addressMode : CPU::zeropage},
    0x08: {instruction: CPU::PHP, text : 'PHP', addressMode: CPU::implied, desc :'PHP implied'},
    0x09: {instruction: CPU::ORA, text : 'ORA', addressMode: CPU::immediate, desc :'ORA immediate'},
    0x0A: {instruction: CPU::ASL, text : 'ASL', addressMode: CPU::accumulator, desc :'ASL accumulator'},
  #0x0B: { instruction : CPU::ANC,addressMode : CPU::immediate},
  #0x0C: { instruction : CPU::NOP,addressMode : CPU::absolute},
    0x0D: {instruction: CPU::ORA, text : 'ORA', addressMode: CPU::absolute, desc :'ORA absolute'},
    0x0E: {instruction: CPU::ASL, text : 'ASL', addressMode: CPU::absolute, desc :'ASL absolute'},
  #0x0F: { instruction : CPU::SLO,addressMode : CPU::absolute},
    0x10: {instruction: CPU::BPL, text : 'BPL', addressMode: CPU::relative, desc :'BPL relative'},
    0x11: {instruction: CPU::ORA, text : 'ORA', addressMode: CPU::indirectY, desc :'ORA indirectY'},
  #0x13: { instruction : CPU::SLO ,addressMode : CPU::indirectY},
  #0x14: { instruction : CPU::NOP,addressMode : CPU::indirectX},
    0x15: {instruction: CPU::ORA, text : 'ORA', addressMode: CPU::indirectX, desc :'ORA indirectX'},
    0x16: {instruction: CPU::ASL, text : 'ASL', addressMode: CPU::indirectX, desc :'ASL indirectX'},
  #0x17: { instruction : CPU::SLO,addressMode : CPU::indirectX},
    0x18: {instruction: CPU::CLC, text : 'CLC', addressMode: CPU::implied, desc :'CLC implied'},
    0x19: {instruction: CPU::ORA, text : 'ORA', addressMode: CPU::absoluteY, desc :'ORA absoluteY'},
  #0x1A: { instruction : CPU::NOP},
  #0x1B: { instruction : CPU::SLO,addressMode : CPU::absoluteY},
  #0x1C: { instruction : CPU::NOP,addressMode : CPU::absoluteX},
    0x1D: {instruction: CPU::ORA, text : 'ORA', addressMode: CPU::absoluteX, desc :'ORA absoluteX'},
    0x1E: {instruction: CPU::ASL, text : 'ASL', addressMode: CPU::absoluteX, desc :'ASL absoluteX'},
  #0x1F: { instruction : CPU::SLO,addressMode : CPU::absoluteX},
    0x20: {instruction: CPU::JSR, text : 'JSR', addressMode: CPU::absolute, desc :'JSR absolute'},
    0x21: {instruction: CPU::AND, text : 'AND', addressMode: CPU::indirect, desc :'AND indirect'},
  #0x23: { instruction : CPU::RLA,addressMode : CPU::indirect},
    0x24: {instruction: CPU::BIT, text : 'BIT', addressMode: CPU::zeropage, desc :'BIT zeropage'},
    0x25: {instruction: CPU::AND, text : 'AND', addressMode: CPU::zeropage, desc :'AND zeropage'},
    0x26: {instruction: CPU::ROL, text : 'ROL', addressMode: CPU::zeropage, desc :'ROL zeropage'},
  #0x27: { instruction : CPU::RLA,addressMode : CPU::zeropage},
    0x28: {instruction: CPU::PLP, text : 'PLP', addressMode: CPU::implied, desc :'PLP implied'},
    0x29: {instruction: CPU::AND, text : 'AND', addressMode: CPU::immediate, desc :'AND immediate'},
    0x2A: {instruction: CPU::ROL, text : 'ROL', addressMode: CPU::accumulator, desc :'ROL accumulator'},
  #0x2B: { instruction : CPU::ANC,addressMode : CPU::immediate},
    0x2C: {instruction: CPU::BIT, text : 'BIT', addressMode: CPU::absolute, desc :'BIT absolute'},
    0x2D: {instruction: CPU::AND, text : 'AND', addressMode: CPU::absolute, desc :'AND absolute'},
    0x2E: {instruction: CPU::ROL, text : 'ROL', addressMode: CPU::absolute, desc :'ROL absolute'},
  #0x2F: { instruction : CPU::RLA,addressMode : CPU::absolute},
    0x30: {instruction: CPU::BMI, text : 'BMI', addressMode: CPU::relative, desc :'BMI relative'},
    0x31: {instruction: CPU::AND, text : 'AND', addressMode: CPU::indirectY, desc :'AND indirectY'},
  #0x33: { instruction : CPU::RLA ,addressMode : CPU::indirectY},
  #0x34: { instruction : CPU::NOP,addressMode : CPU::indirectX},
    0x35: {instruction: CPU::AND, text : 'AND', addressMode: CPU::indirectX, desc :'AND indirectX'},
    0x36: {instruction: CPU::ROL, text : 'ROL', addressMode: CPU::indirectX, desc :'ROL indirectX'},
  #0x37: { instruction : CPU::RLA,addressMode : CPU::indirectX},
    0x38: {instruction: CPU::SEC, text : 'SEC', addressMode: CPU::implied, desc :'SEC implied'},
    0x39: {instruction: CPU::AND, text : 'AND', addressMode: CPU::absoluteY, desc :'AND absoluteY'},
  #0x3A: { instruction : CPU::NOP},
  #0x3B: { instruction : CPU::RLA,addressMode : CPU::absoluteY},
    0x3C: {instruction: CPU::NOP, text : 'NOP', addressMode: CPU::absoluteX, desc :'NOP absoluteX'},
    0x3D: {instruction: CPU::AND, text : 'AND', addressMode: CPU::absoluteX, desc :'AND absoluteX'},
    0x3E: {instruction: CPU::ROL, text : 'ROL', addressMode: CPU::absoluteX, desc :'ROL absoluteX'},
  #0x3F: { instruction : CPU::RLA,addressMode : CPU::absoluteX},
    0x40: {instruction: CPU::RTI, text : 'RTI', addressMode: CPU::implied, desc :'RTI implied'},
    0x41: {instruction: CPU::EOR, text : 'EOR', addressMode: CPU::indirect, desc :'EOR indirect'},
  #0x43: { instruction : CPU::SRE,addressMode : CPU::indirect},
  #0x44: { instruction : CPU::NOP,addressMode : CPU::zeropage},
    0x45: {instruction: CPU::EOR, text : 'EOR', addressMode: CPU::zeropage, desc :'EOR zeropage'},
    0x46: {instruction: CPU::LSR, text : 'LSR', addressMode: CPU::zeropage, desc :'LSR zeropage'},
  #0x47: { instruction : CPU::SRE,addressMode : CPU::zeropage},
    0x48: {instruction: CPU::PHA, text : 'PHA', addressMode: CPU::implied, desc :'PHA implied'},
    0x49: {instruction: CPU::EOR, text : 'EOR', addressMode: CPU::immediate, desc :'EOR immediate'},
    0x4A: {instruction: CPU::LSR, text : 'LSR', addressMode: CPU::accumulator, desc :'LSR accumulator'},
  #0x4B: { instruction : CPU::ASR,addressMode : CPU::immediate},
    0x4C: {instruction: CPU::JMP, text : 'JMP', addressMode: CPU::absolute, desc :'JMP absolute'},
    0x4D: {instruction: CPU::EOR, text : 'EOR', addressMode: CPU::absolute, desc :'EOR absolute'},
    0x4E: {instruction: CPU::LSR, text : 'LSR', addressMode: CPU::absolute, desc :'LSR absolute'},
  #0x4F: { instruction : CPU::SRE,addressMode : CPU::absolute},
    0x50: {instruction: CPU::BVC, text : 'BVC', addressMode: CPU::relative, desc :'BVC relative'},
    0x51: {instruction: CPU::EOR, text : 'EOR', addressMode: CPU::indirectY, desc :'EOR indirectY'},
  #0x53: { instruction : CPU::SRE ,addressMode : CPU::indirectY},
  #0x54: { instruction : CPU::NOP,addressMode : CPU::indirectX},
    0x55: {instruction: CPU::EOR, text : 'EOR', addressMode: CPU::indirectX, desc :'EOR indirectX'},
    0x56: {instruction: CPU::LSR, text : 'LSR', addressMode: CPU::indirectX, desc :'LSR indirectX'},
  #0x57: { instruction : CPU::SRE,addressMode : CPU::indirectX},
    0x58: {instruction: CPU::CLI, text : 'CLI', addressMode: CPU::implied, desc :'CLI implied'},
    0x59: {instruction: CPU::EOR, text : 'EOR', addressMode: CPU::absoluteY, desc :'EOR absoluteY'},
  #0x5A: { instruction : CPU::NOP},
  #0x5B: { instruction : CPU::SRE,addressMode : CPU::absoluteY},
  #0x5C: { instruction : CPU::NOP,addressMode : CPU::absoluteX},
    0x5D: {instruction: CPU::EOR, text : 'EOR', addressMode: CPU::absoluteX, desc :'EOR absoluteX'},
    0x5E: {instruction: CPU::LSR, text : 'LSR', addressMode: CPU::absoluteX, desc :'LSR absoluteX'},
  #0x5F: { instruction : CPU::SRE,addressMode : CPU::absoluteX},
    0x60: {instruction: CPU::RTS, text : 'RTS', addressMode: CPU::implied, desc :'RTS implied'},
    0x61: {instruction: CPU::ADC, text : 'ADC', addressMode: CPU::indirect, desc :'ADC indirect'},
  #0x63: { instruction : CPU::RRA,addressMode : CPU::indirect},
  #0x64: { instruction : CPU::NOP,addressMode : CPU::zeropage},
    0x65: {instruction: CPU::ADC, text : 'ADC', addressMode: CPU::zeropage, desc :'ADC zeropage'},
    0x66: {instruction: CPU::ROR, text : 'ROR', addressMode: CPU::zeropage, desc :'ROR zeropage'},
  #0x67: { instruction : CPU::RRA,addressMode : CPU::zeropage},
    0x68: {instruction: CPU::PLA, text : 'PLA', addressMode: CPU::implied, desc :'PLA implied'},
    0x69: {instruction: CPU::ADC, text : 'ADC', addressMode: CPU::immediate, desc :'ADC immediate'},
    0x6A: {instruction: CPU::ROR, text : 'ROR', addressMode: CPU::accumulator, desc :'ROR accumulator'},
  #0x6B: { instruction : CPU::ARR,addressMode : CPU::immediate},
    0x6C: {instruction: CPU::JMP, text : 'JMP', addressMode: CPU::indirect, desc :'JMP indirect'},
    0x6D: {instruction: CPU::ADC, text : 'ADC', addressMode: CPU::absolute, desc :'ADC absolute'},
    0x6E: {instruction: CPU::ROR, text : 'ROR', addressMode: CPU::absolute, desc :'ROR absolute'},
  #0x6F: { instruction : CPU::RRA,addressMode : CPU::absolute},
    0x70: {instruction: CPU::BVS, text : 'BVS', addressMode: CPU::relative, desc :'BVS relative'},
    0x71: {instruction: CPU::ADC, text : 'ADC', addressMode: CPU::indirectY, desc :'ADC indirectY'},
  #0x73: { instruction : CPU::RRA ,addressMode : CPU::indirectY},
  #0x74: { instruction : CPU::NOP,addressMode : CPU::indirectX},
    0x75: {instruction: CPU::ADC, text : 'ADC', addressMode: CPU::indirectX, desc :'ADC indirectX'},
    0x76: {instruction: CPU::ROR, text : 'ROR', addressMode: CPU::indirectX, desc :'ROR indirectX'},
  #0x77: { instruction : CPU::RRA,addressMode : CPU::indirectX},
    0x78: {instruction: CPU::SEI, text : 'SEI', addressMode: CPU::implied, desc :'SEI implied'},
    0x79: {instruction: CPU::ADC, text : 'ADC', addressMode: CPU::absoluteY, desc :'ADC absoluteY'},
  #0x7A: { instruction : CPU::NOP},
  #0x7B: { instruction : CPU::RRA,addressMode : CPU::absoluteY},
  #0x7C: { instruction : CPU::NOP,addressMode : CPU::absoluteX},
    0x7D: {instruction: CPU::ADC, text : 'ADC', addressMode: CPU::absoluteX, desc :'ADC absoluteX'},
    0x7E: {instruction: CPU::ROR, text : 'ROR', addressMode: CPU::absoluteX, desc :'ROR absoluteX'},
  #0x7F: { instruction : CPU::RRA,addressMode : CPU::absoluteX},
  #0x80: { instruction : CPU::NOP,addressMode : CPU::immediate},
    0x81: {instruction: CPU::STA, text : 'STA', addressMode: CPU::indirect, desc :'STA indirect'},
    0x82: {instruction: CPU::NOP, text : 'NOP', addressMode: CPU::immediate, desc :'NOP immediate'},
  #0x83: { instruction : CPU::SAX,addressMode : CPU::indirect},
    0x84: {instruction: CPU::STY, text : 'STY', addressMode: CPU::zeropage, desc :'STY zeropage'},
    0x85: {instruction: CPU::STA, text : 'STA', addressMode: CPU::zeropage, desc :'STA zeropage'},
    0x86: {instruction: CPU::STX, text : 'STX', addressMode: CPU::zeropage, desc :'STX zeropage'},
  #0x87: { instruction : CPU::SAX,addressMode : CPU::zeropage},
    0x88: {instruction: CPU::DEY, text : 'DEY', addressMode: CPU::implied, desc :'DEY implied'},
  #0x89: { instruction : CPU::NOP,addressMode : CPU::immediate},
    0x8A: {instruction: CPU::TXA, text : 'TXA', addressMode: CPU::implied, desc :'TXA implied'},
  #0x8B: { instruction : CPU::ANE,addressMode : CPU::immediate},
    0x8C: {instruction: CPU::STY, text : 'STY', addressMode: CPU::absolute, desc :'STY absolute'},
    0x8D: {instruction: CPU::STA, text : 'STA', addressMode: CPU::absolute, desc :'STA absolute'},
    0x8E: {instruction: CPU::STX, text : 'STX', addressMode: CPU::absolute, desc :'STX absolute'},
  #0x8F: { instruction : CPU::SAX,addressMode : CPU::absolute},
    0x90: {instruction: CPU::BCC, text : 'BCC', addressMode: CPU::relative, desc :'BCC relative'},
    0x91: {instruction: CPU::STA, text : 'STA', addressMode: CPU::indirectY, desc :'STA indirectY'},
  #0x93: { instruction : CPU::SHA ,addressMode : CPU::indirectY},
    0x94: {instruction: CPU::STY, text : 'STY', addressMode: CPU::indirectX, desc :'STY indirectX'},
    0x95: {instruction: CPU::STA, text : 'STA', addressMode: CPU::indirectX, desc :'STA indirectX'},
    0x96: {instruction: CPU::STX, text : 'STX', addressMode: CPU::zeropageY, desc :'STX zeropageY'},
  #0x97: { instruction : CPU::SAX,addressMode : CPU::zeropageY},
    0x98: {instruction: CPU::TYA, text : 'TYA', addressMode: CPU::implied, desc :'TYA implied'},
    0x99: {instruction: CPU::STA, text : 'STA', addressMode: CPU::absoluteY, desc :'STA absoluteY'},
    0x9A: {instruction: CPU::TXS, text : 'TXS', addressMode: CPU::implied, desc :'TXS implied'},
  #0x9B: { instruction : CPU::SHS,addressMode : CPU::absoluteY},
  #0x9C: { instruction : CPU::SHY,addressMode : CPU::absoluteX},
    0x9D: {instruction: CPU::STA, text : 'STA', addressMode: CPU::absoluteX, desc :'STA absoluteX'},
  #0x9E: { instruction : CPU::SHX,addressMode : CPU::absoluteY},
  #0x9F: { instruction : CPU::SHA,addressMode : CPU::absoluteY},
    0xA0: {instruction: CPU::LDY, text : 'LDY', addressMode: CPU::immediate, desc :'LDY immediate'},
    0xA1: {instruction: CPU::LDA, text : 'LDA', addressMode: CPU::indirect, desc :'LDA indirect'},
    0xA2: {instruction: CPU::LDX, text : 'LDX', addressMode: CPU::immediate, desc :'LDX immediate'},
  #0xA3: { instruction : CPU::LAX,addressMode : CPU::indirect},
    0xA4: {instruction: CPU::LDY, text : 'LDY', addressMode: CPU::zeropage, desc :'LDY zeropage'},
    0xA5: {instruction: CPU::LDA, text : 'LDA', addressMode: CPU::zeropage, desc :'LDA zeropage'},
    0xA6: {instruction: CPU::LDX, text : 'LDX', addressMode: CPU::zeropage, desc :'LDX zeropage'},
  #0xA7: { instruction : CPU::LAX,addressMode : CPU::zeropage},
    0xA8: {instruction: CPU::TAY, text : 'TAY', addressMode: CPU::implied, desc :'TAY implied'},
    0xA9: {instruction: CPU::LDA, text : 'LDA', addressMode: CPU::immediate, desc :'LDA immediate'},
    0xAA: {instruction: CPU::TAX, text : 'TAX', addressMode: CPU::implied, desc :'TAX implied'},
  #0xAB: { instruction : CPU::LAX,addressMode : CPU::immediate},
    0xAC: {instruction: CPU::LDY, text : 'LDY', addressMode: CPU::absolute, desc :'LDY absolute'},
    0xAD: {instruction: CPU::LDA, text : 'LDA', addressMode: CPU::absolute, desc :'LDA absolute'},
    0xAE: {instruction: CPU::LDX, text : 'LDX', addressMode: CPU::absolute, desc :'LDX absolute'},
  #0xAF: { instruction : CPU::LAX,addressMode : CPU::absolute},
    0xB0: {instruction: CPU::BCS, text : 'BCS', addressMode: CPU::relative, desc :'BCS relative'},
    0xB1: {instruction: CPU::LDA, text : 'LDA', addressMode: CPU::indirectY, desc :'LDA indirectY'},
  #0xB3: { instruction : CPU::LAX ,addressMode : CPU::indirectY},
    0xB4: {instruction: CPU::LDY, text : 'LDY', addressMode: CPU::indirectX, desc :'LDY indirectX'},
    0xB5: {instruction: CPU::LDA, text : 'LDA', addressMode: CPU::indirectX, desc :'LDA indirectX'},
    0xB6: {instruction: CPU::LDX, text : 'LDX', addressMode: CPU::zeropageY, desc :'LDX zeropageY'},
  #0xB7: { instruction : CPU::LAX,addressMode : CPU::zeropageY},
    0xB8: {instruction: CPU::CLV, text : 'CLV', addressMode: CPU::implied, desc :'CLV implied'},
    0xB9: {instruction: CPU::LDA, text : 'LDA', addressMode: CPU::absoluteY, desc :'LDA absoluteY'},
    0xBA: {instruction: CPU::TSX, text : 'TSX', addressMode: CPU::implied, desc :'TSX implied'},
  #0xBB: { instruction : CPU::LAS,addressMode : CPU::absoluteY},
    0xBC: {instruction: CPU::LDY, text : 'LDY', addressMode: CPU::absoluteX, desc :'LDY absoluteX'},
    0xBD: {instruction: CPU::LDA, text : 'LDA', addressMode: CPU::absoluteX, desc :'LDA absoluteX'},
    0xBE: {instruction: CPU::LDX, text : 'LDX', addressMode: CPU::absoluteY, desc :'LDX absoluteY'},
  #0xBF: { instruction : CPU::LAX,addressMode : CPU::absoluteY},
    0xC0: {instruction: CPU::CPY, text : 'CPY', addressMode: CPU::immediate, desc :'CPY immediate'},
    0xC1: {instruction: CPU::CMP, text : 'CMP', addressMode: CPU::indirect, desc :'CMP indirect'},
    0xC2: {instruction: CPU::NOP, text : 'NOP', addressMode: CPU::immediate, desc :'NOP immediate'},
  #0xC3: { instruction : CPU::DCP,addressMode : CPU::indirect},
    0xC4: {instruction: CPU::CPY, text : 'CPY', addressMode: CPU::zeropage, desc :'CPY zeropage'},
    0xC5: {instruction: CPU::CMP, text : 'CMP', addressMode: CPU::zeropage, desc :'CMP zeropage'},
    0xC6: {instruction: CPU::DEC, text : 'DEC', addressMode: CPU::zeropage, desc :'DEC zeropage'},
  #0xC7: { instruction : CPU::DCP,addressMode : CPU::zeropage},
    0xC8: {instruction: CPU::INY, text : 'INY', addressMode: CPU::implied, desc :'INY implied'},
    0xC9: {instruction: CPU::CMP, text : 'CMP', addressMode: CPU::immediate, desc :'CMP immediate'},
    0xCA: {instruction: CPU::DEX, text : 'DEX', addressMode: CPU::implied, desc :'DEX implied'},
  #0xCB: { instruction : CPU::SBX,addressMode : CPU::immediate},
    0xCC: {instruction: CPU::CPY, text : 'CPY', addressMode: CPU::absolute, desc :'CPY absolute'},
    0xCD: {instruction: CPU::CMP, text : 'CMP', addressMode: CPU::absolute, desc :'CMP absolute'},
    0xCE: {instruction: CPU::DEC, text : 'DEC', addressMode: CPU::absolute, desc :'DEC absolute'},
  #0xCF: { instruction : CPU::DCP,addressMode : CPU::absolute},
    0xD0: {instruction: CPU::BNE, text : 'BNE', addressMode: CPU::relative, desc :'BNE relative'},
    0xD1: {instruction: CPU::CMP, text : 'CMP', addressMode: CPU::indirectY, desc :'CMP indirectY'},
  #0xD3: { instruction : CPU::DCP ,addressMode : CPU::indirectY},
  #0xD4: { instruction : CPU::NOP,addressMode : CPU::indirectX},
    0xD5: {instruction: CPU::CMP, text : 'CMP', addressMode: CPU::indirectX, desc :'CMP indirectX'},
    0xD6: {instruction: CPU::DEC, text : 'DEC', addressMode: CPU::indirectX, desc :'DEC indirectX'},
  #0xD7: { instruction : CPU::DCP,addressMode : CPU::indirectX},
    0xD8: {instruction: CPU::CLD, text : 'CLD', addressMode: CPU::implied, desc :'CLD implied'},
    0xD9: {instruction: CPU::CMP, text : 'CMP', addressMode: CPU::absoluteY, desc :'CMP absoluteY'},
  #0xDA: { instruction : CPU::NOP},
  #0xDB: { instruction : CPU::DCP,addressMode : CPU::absoluteY},
  #0xDC: { instruction : CPU::NOP,addressMode : CPU::absoluteX},
    0xDD: {instruction: CPU::CMP, text : 'CMP', addressMode: CPU::absoluteX, desc :'CMP absoluteX'},
    0xDE: {instruction: CPU::DEC, text : 'DEC', addressMode: CPU::absoluteX, desc :'DEC absoluteX'},
  #0xDF: { instruction : CPU::DCP,addressMode : CPU::absoluteX},
    0xE0: {instruction: CPU::CPX, text : 'CPX', addressMode: CPU::immediate, desc :'CPX immediate'},
    0xE1: {instruction: CPU::SBC, text : 'SBC', addressMode: CPU::indirect, desc :'SBC indirect'},
    0xE2: {instruction: CPU::NOP, text : 'NOP', addressMode: CPU::immediate, desc :'NOP immediate'},
  #0xE3: { instruction : CPU::ISB,addressMode : CPU::indirect},
    0xE4: {instruction: CPU::CPX, text : 'CPX', addressMode: CPU::zeropage, desc :'CPX zeropage'},
    0xE5: {instruction: CPU::SBC, text : 'SBC', addressMode: CPU::zeropage, desc :'SBC zeropage'},
    0xE6: {instruction: CPU::INC, text : 'INC', addressMode: CPU::zeropage, desc :'INC zeropage'},
  #0xE7: { instruction : CPU::ISB,addressMode : CPU::zeropage},
    0xE8: {instruction: CPU::INX, text : 'INX', addressMode: CPU::implied, desc :'INX implied'},
    0xE9: {instruction: CPU::SBC, text : 'SBC', addressMode: CPU::immediate, desc :'SBC immediate'},
    0xEA: {instruction: CPU::NOP, text : 'NOP', addressMode: CPU::implied, desc :'NOP implied'},
  #0xEB: { instruction : CPU::SBC,addressMode : CPU::immediate},
    0xEC: {instruction: CPU::CPX, text : 'CPX', addressMode: CPU::absolute, desc :'CPX absolute'},
    0xED: {instruction: CPU::SBC, text : 'SBC', addressMode: CPU::absolute, desc :'SBC absolute'},
    0xEE: {instruction: CPU::INC, text : 'INC', addressMode: CPU::absolute, desc :'INC absolute'},
  #0xEF: { instruction : CPU::ISB,addressMode : CPU::absolute},
    0xF0: {instruction: CPU::BEQ, text : 'BEQ', addressMode: CPU::relative, desc :'BEQ relative'},
    0xF1: {instruction: CPU::SBC, text : 'SBC', addressMode: CPU::indirectY, desc :'SBC indirectY'},
  #0xF3: { instruction : CPU::ISB ,addressMode : CPU::indirectY},
    0xF4: {instruction: CPU::NOP, text : 'NOP', addressMode: CPU::zeropageX, desc :'NOP zeropageX'},
    0xF5: {instruction: CPU::SBC, text : 'SBC', addressMode: CPU::indirectX, desc :'SBC indirectX'},
    0xF6: {instruction: CPU::INC, text : 'INC', addressMode: CPU::indirectX, desc :'INC indirectX'},
  #0xF7: { instruction : CPU::ISB,addressMode : CPU::indirectX},
    0xF8: {instruction: CPU::SED, text : 'SED', addressMode: CPU::implied, desc :'SED implied'},
    0xF9: {instruction: CPU::SBC, text : 'SBC', addressMode: CPU::absoluteY, desc :'SBC absoluteY'},
  #0xFA: { instruction : CPU::NOP},
  #0xFB: { instruction : CPU::ISB,addressMode : CPU::absoluteY},
  #0xFC: { instruction : CPU::NOP,addressMode : CPU::absoluteX},
    0xFD: {instruction: CPU::SBC, text : 'SBC', addressMode: CPU::absoluteX, desc :'SBC absoluteX'},
    0xFE: {instruction: CPU::INC, text : 'INC', addressMode: CPU::absoluteX, desc :'INC absoluteX'},
  #0xFF: { instruction : CPU::ISB abs,x}

  }

exports.CPU = CPU
exports.OPRCODES = CPU::OPRCODES