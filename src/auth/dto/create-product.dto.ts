import { IsString, IsNumber, IsNotEmpty, IsOptional, Min, Max, Length } from 'class-validator';

export class CreateProductDto {
  @IsString()
  @IsNotEmpty()
  @Length(3, 100)
  name: string;

  @IsString()
  @Length(0, 500)
  description: string;

  @IsNumber()
  @IsNotEmpty()
  @Min(0.01)
  @Max(999999.99)
  price: number;

  @IsNumber()
  @IsNotEmpty()
  @Min(0)
  stock: number;

  @IsString()
  @IsOptional()
  @Length(0, 50)
  category?: string;
}