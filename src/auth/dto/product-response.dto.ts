import { Exclude, Expose } from 'class-transformer';

export class ProductResponseDto {
  id: number;
  name: string;
  price: number;

  @Exclude() description: string;
  @Exclude() stock: number;
}